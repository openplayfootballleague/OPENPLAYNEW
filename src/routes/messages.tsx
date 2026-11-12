import { useCallback, useEffect, useMemo, useState } from "react";
import { Link, createFileRoute } from "@tanstack/react-router";
import type { SupabaseClient } from "@supabase/supabase-js";
import { useRequiredSession } from "../lib/auth/use-required-session";
import { getSupabaseClient } from "../lib/supabase/client";

type Conversation = {
  conversation_id: string;
  kind: "direct" | "team" | "support" | "announcement";
  title: string;
  season_team_id: string | null;
  created_at: string;
  updated_at: string;
  last_message_id: string | null;
  last_message_body: string | null;
  last_message_at: string | null;
  last_message_sender_id: string | null;
  unread_count: number;
  participant_count: number;
  other_participant_user_id: string | null;
  other_participant_name: string | null;
  other_participant_last_read_at: string | null;
  read_by_count: number;
};
type MessageRow = {
  message_id: string;
  conversation_id: string;
  sender_id: string | null;
  sender_name: string;
  body: string;
  message_type: "message" | "announcement";
  is_hidden: boolean;
  created_at: string;
};
type Recipient = { user_id: string; display_name: string; shared_team_name: string };
type BlockedUser = { user_id: string; display_name: string; blocked_at: string };
type MessagingRpcClient = { rpc: (name: string, args?: Record<string, unknown>) => Promise<{ data: unknown; error: { message: string } | null }> };
const messagingRpc = () => getSupabaseClient() as unknown as MessagingRpcClient;

export const Route = createFileRoute("/messages")({ component: MessagesPage });

function MessagesPage() {
  const authStatus = useRequiredSession();
  const [userId, setUserId] = useState("");
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [selectedId, setSelectedId] = useState("");
  const [messages, setMessages] = useState<MessageRow[]>([]);
  const [hasMoreMessages, setHasMoreMessages] = useState(false);
  const [olderLoading, setOlderLoading] = useState(false);
  const [blockedUsers, setBlockedUsers] = useState<BlockedUser[]>([]);
  const [isAdmin, setIsAdmin] = useState(false);
  const [captainTeams, setCaptainTeams] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [threadLoading, setThreadLoading] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [composer, setComposer] = useState("");
  const [announcement, setAnnouncement] = useState(false);
  const [busy, setBusy] = useState(false);
  const [showDirectSearch, setShowDirectSearch] = useState(false);
  const [recipientQuery, setRecipientQuery] = useState("");
  const [recipients, setRecipients] = useState<Recipient[]>([]);
  const [recipientSearchBusy, setRecipientSearchBusy] = useState(false);
  const [showSupportForm, setShowSupportForm] = useState(false);
  const [supportSubject, setSupportSubject] = useState("");
  const [supportBody, setSupportBody] = useState("");
  const [reportingId, setReportingId] = useState("");
  const [reportReason, setReportReason] = useState("");

  const loadConversations = useCallback(async () => {
    const { data, error: rpcError } = await messagingRpc().rpc("get_my_message_conversations", { p_limit: 100 });
    if (rpcError) throw rpcError;
    const rows = (data ?? []) as Conversation[];
    setConversations(rows);
    setSelectedId((current) => current && rows.some((row) => row.conversation_id === current)
      ? current
      : rows[0]?.conversation_id ?? "");
  }, []);

  const loadBlockedUsers = useCallback(async () => {
    const { data, error: rpcError } = await messagingRpc().rpc("get_my_blocked_message_users");
    if (rpcError) throw rpcError;
    setBlockedUsers((data ?? []) as BlockedUser[]);
  }, []);

  const loadMessages = useCallback(async (conversationId: string) => {
    if (!conversationId) { setMessages([]); return; }
    setThreadLoading(true);
    const { data, error: rpcError } = await messagingRpc().rpc("get_message_history", {
      p_conversation_id: conversationId,
      p_limit: 100,
      p_before: null,
      p_before_id: null,
    });
    if (rpcError) {
      setError(rpcError.message);
      setMessages([]);
    } else {
      const rows = (data ?? []) as MessageRow[];
      setMessages(rows.slice().reverse());
      setHasMoreMessages(rows.length === 100);
    }
    setThreadLoading(false);
  }, []);

  async function loadOlderMessages() {
    if (!selectedId || !messages.length || olderLoading) return;
    setOlderLoading(true); setError("");
    const { data, error: rpcError } = await messagingRpc().rpc("get_message_history", {
      p_conversation_id: selectedId,
      p_limit: 100,
      p_before: messages[0].created_at,
      p_before_id: messages[0].message_id,
    });
    if (rpcError) setError(rpcError.message);
    else {
      const older = ((data ?? []) as MessageRow[]).slice().reverse();
      setMessages((current) => {
        const currentIds = new Set(current.map((message) => message.message_id));
        return [...older.filter((message) => !currentIds.has(message.message_id)), ...current];
      });
      setHasMoreMessages(older.length === 100);
    }
    setOlderLoading(false);
  }

  useEffect(() => {
    if (authStatus !== "authenticated") {
      if (authStatus === "unauthenticated") setLoading(false);
      return;
    }
    let active = true;
    const supabase = getSupabaseClient();
    void (async () => {
      const { data: { session }, error: sessionError } = await supabase.auth.getSession();
      if (!active) return;
      if (sessionError || !session) {
        setError(sessionError?.message ?? "Sign in to access messages.");
        setLoading(false);
        return;
      }
      setUserId(session.user.id);
      const [{ data: roleRows, error: roleError }, { data: membershipRows, error: membershipError }] = await Promise.all([
        supabase.from("user_roles").select("role").eq("user_id", session.user.id),
        supabase.from("team_memberships").select("season_team_id,is_captain,status").eq("user_id", session.user.id).eq("status", "active"),
      ]);
      if (!active) return;
      if (roleError || membershipError) setError(roleError?.message ?? membershipError?.message ?? "Unable to load messaging permissions.");
      setIsAdmin((roleRows ?? []).some((row) => ["admin", "super_admin", "league_admin"].includes(row.role)));
      setCaptainTeams((membershipRows ?? []).filter((row) => row.is_captain).map((row) => row.season_team_id));
      try {
        await Promise.all([loadConversations(), loadBlockedUsers()]);
      } catch (cause) {
        setError(cause instanceof Error ? cause.message : "Unable to load your messages.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => { active = false; };
  }, [authStatus, loadConversations, loadBlockedUsers]);

  useEffect(() => {
    if (!selectedId) { setMessages([]); return; }
    let active = true;
    const supabase = getSupabaseClient() as unknown as SupabaseClient<any>;
    void (async () => {
      await supabase.rpc("mark_message_conversation_read", { p_conversation_id: selectedId });
      if (!active) return;
      await loadMessages(selectedId);
      await loadConversations();
    })();
    const channel = supabase.channel("message-thread-" + selectedId)
      .on("postgres_changes", {
        event: "*",
        schema: "public",
        table: "messages",
        filter: "conversation_id=eq." + selectedId,
      }, () => {
        if (active) {
          void loadMessages(selectedId);
          void loadConversations();
          void supabase.rpc("mark_message_conversation_read", { p_conversation_id: selectedId });
        }
      })
      .subscribe();
    return () => {
      active = false;
      void supabase.removeChannel(channel);
    };
  }, [selectedId, loadMessages, loadConversations]);

  useEffect(() => {
    if (!userId) return;
    const supabase = getSupabaseClient() as unknown as SupabaseClient<any>;
    const channel = supabase.channel("message-inbox-" + userId)
      .on("postgres_changes", {
        event: "*",
        schema: "public",
        table: "message_conversation_participants",
        filter: "user_id=eq." + userId,
      }, () => { void loadConversations(); })
      .subscribe();
    return () => { void supabase.removeChannel(channel); };
  }, [userId, loadConversations]);

  const selected = useMemo(
    () => conversations.find((row) => row.conversation_id === selectedId) ?? null,
    [conversations, selectedId],
  );
  const canAnnounce = Boolean(selected?.kind === "team" && (
    (selected.season_team_id && captainTeams.includes(selected.season_team_id)) || isAdmin
  ));

  async function searchRecipients(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (recipientQuery.trim().length < 2) {
      setError("Enter at least two characters to search your active teammates.");
      return;
    }
    setRecipientSearchBusy(true);
    setError("");
    const { data, error: rpcError } = await messagingRpc().rpc("search_message_recipients", {
      p_query: recipientQuery.trim(),
      p_limit: 20,
    });
    if (rpcError) setError(rpcError.message);
    else setRecipients((data ?? []) as Recipient[]);
    setRecipientSearchBusy(false);
  }

  async function startDirectMessage(recipientId: string) {
    setBusy(true); setError(""); setNotice("");
    const { data, error: rpcError } = await messagingRpc().rpc("create_direct_message_conversation", {
      p_recipient_user_id: recipientId,
    });
    if (rpcError) setError(rpcError.message);
    else {
      setShowDirectSearch(false); setRecipientQuery(""); setRecipients([]);
      await loadConversations();
      setSelectedId(data as string);
      setNotice("Private conversation opened.");
    }
    setBusy(false);
  }

  async function openSupportConversation(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true); setError(""); setNotice("");
    const { data, error: rpcError } = await messagingRpc().rpc("create_support_message_conversation", {
      p_subject: supportSubject.trim(),
      p_initial_message: supportBody.trim(),
    });
    if (rpcError) setError(rpcError.message);
    else {
      setShowSupportForm(false); setSupportSubject(""); setSupportBody("");
      await loadConversations();
      setSelectedId(data as string);
      setNotice("Your private support conversation has been opened.");
    }
    setBusy(false);
  }

  async function sendMessage(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selected || !composer.trim()) return;
    setBusy(true); setError(""); setNotice("");
    const { error: rpcError } = await messagingRpc().rpc("send_message", {
      p_conversation_id: selected.conversation_id,
      p_body: composer.trim(),
      p_message_type: announcement ? "announcement" : "message",
    });
    if (rpcError) setError(rpcError.message);
    else {
      setComposer(""); setAnnouncement(false);
      await loadMessages(selected.conversation_id);
      await loadConversations();
    }
    setBusy(false);
  }

  async function reportMessage(messageId: string) {
    if (reportReason.trim().length < 5) {
      setError("Please give a reason of at least five characters.");
      return;
    }
    setBusy(true); setError(""); setNotice("");
    const { error: rpcError } = await messagingRpc().rpc("report_message", {
      p_message_id: messageId,
      p_reason: reportReason.trim(),
    });
    if (rpcError) setError(rpcError.message);
    else {
      setNotice("Message reported to the Open Play moderation team.");
      setReportingId(""); setReportReason("");
    }
    setBusy(false);
  }

  async function blockParticipant() {
    if (!selected?.other_participant_user_id) return;
    if (!window.confirm("Block " + (selected.other_participant_name ?? "this member") + "? They will not be able to send you direct messages.")) return;
    setBusy(true); setError(""); setNotice("");
    const { error: rpcError } = await messagingRpc().rpc("block_message_user", {
      p_blocked_user_id: selected.other_participant_user_id,
    });
    if (rpcError) setError(rpcError.message);
    else {
      setNotice("Member blocked. Direct messaging between you is paused.");
      await loadBlockedUsers();
    }
    setBusy(false);
  }

  async function unblockParticipant(blockedId: string) {
    setBusy(true); setError(""); setNotice("");
    const { error: rpcError } = await messagingRpc().rpc("unblock_message_user", {
      p_blocked_user_id: blockedId,
    });
    if (rpcError) setError(rpcError.message);
    else {
      setNotice("Member unblocked.");
      await loadBlockedUsers();
    }
    setBusy(false);
  }

  if (authStatus === "loading" || loading) {
    return <main className="notice-page player-facing"><section className="notice-panel"><p>Loading messages…</p></section></main>;
  }
  if (authStatus === "unauthenticated") {
    return <main className="notice-page player-facing"><section className="notice-panel"><Link className="notice-brand" to="/"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play"/></Link><p className="eyebrow eyebrow-dark">MESSAGES</p><h1>Sign in to<br/><em>continue.</em></h1><p className="form-note">Private Open Play messages are available to registered members.</p><Link className="button" to="/sign-in">SIGN IN</Link></section></main>;
  }

  return (
    <main className="notice-page player-facing">
      <section className="notice-panel messaging-panel">
        <div className="hub-top">
          <Link className="notice-brand" to="/more"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play"/></Link>
          <Link className="messaging-back-link" to="/more">MORE</Link>
        </div>
        <p className="eyebrow eyebrow-dark">OPEN PLAY MEMBERS</p>
        <h1>Messages<br/><em>that matter.</em></h1>
        <p className="form-note">Private messages are limited to active teammates. Team groups follow squad membership. Use private support for help from the admin team.</p>
        {error && <p className="form-error" role="alert">{error}</p>}
        {notice && <p className="form-success" role="status">{notice}</p>}
        <div className="messaging-layout">
          <aside className="messaging-sidebar">
            <div className="messaging-actions">
              <button type="button" onClick={() => { setShowDirectSearch((v) => !v); setShowSupportForm(false); setError(""); }}>NEW DIRECT MESSAGE</button>
              <button type="button" className="secondary" onClick={() => { setShowSupportForm((v) => !v); setShowDirectSearch(false); setError(""); }}>CONTACT ADMIN SUPPORT</button>
            </div>
            {showDirectSearch && <form className="messaging-inline-form" onSubmit={searchRecipients}>
              <label>Find a teammate<input value={recipientQuery} onChange={(event) => setRecipientQuery(event.target.value)} placeholder="Search by player name" minLength={2}/></label>
              <button type="submit" disabled={recipientSearchBusy}>{recipientSearchBusy ? "SEARCHING…" : "SEARCH"}</button>
              {recipients.map((recipient) => <button className="messaging-recipient" type="button" key={recipient.user_id} disabled={busy} onClick={() => void startDirectMessage(recipient.user_id)}><strong>{recipient.display_name}</strong><small>{recipient.shared_team_name}</small></button>)}
              {recipients.length === 0 && recipientQuery.trim().length>=2 && !recipientSearchBusy && <small>No eligible teammates found.</small>}
            </form>}
            {showSupportForm && <form className="messaging-inline-form" onSubmit={openSupportConversation}>
              <label>Subject<input value={supportSubject} onChange={(event) => setSupportSubject(event.target.value)} minLength={3} maxLength={120} required placeholder="What do you need help with?"/></label>
              <label>Message<textarea value={supportBody} onChange={(event) => setSupportBody(event.target.value)} maxLength={2000} required rows={4} placeholder="Explain what happened…"/></label>
              <button type="submit" disabled={busy}>{busy ? "SENDING…" : "OPEN PRIVATE SUPPORT THREAD"}</button>
            </form>}
            <div className="messaging-list-heading"><strong>YOUR CONVERSATIONS</strong><span>{conversations.length}</span></div>
            <div className="messaging-conversation-list">
              {conversations.map((conversation) => <button type="button" key={conversation.conversation_id} className={selectedId===conversation.conversation_id?"messaging-conversation selected":"messaging-conversation"} onClick={() => { setSelectedId(conversation.conversation_id); setAnnouncement(false); setError(""); }}>
                <span className="messaging-conversation-top"><strong>{conversation.kind==="direct"?(conversation.other_participant_name??"Direct conversation"):conversation.title}</strong>{conversation.unread_count>0&&<b>{conversation.unread_count}</b>}</span>
                <small>{conversation.kind==="team"?"TEAM GROUP":conversation.kind==="support"?"ADMIN SUPPORT":conversation.kind==="announcement"?"ADMIN ANNOUNCEMENT":"DIRECT MESSAGE"}</small>
                <span className="messaging-preview">{conversation.last_message_body??"No messages yet"}</span>
              </button>)}
              {conversations.length===0&&<p className="form-note">No conversations yet. Start a teammate message or contact admin support.</p>}
            </div>
            {blockedUsers.length>0&&<details className="messaging-blocked-list"><summary>BLOCKED MEMBERS ({blockedUsers.length})</summary>{blockedUsers.map((blocked)=><div key={blocked.user_id}><span>{blocked.display_name}</span><button type="button" disabled={busy} onClick={()=>void unblockParticipant(blocked.user_id)}>UNBLOCK</button></div>)}</details>}
          </aside>
          <section className="messaging-thread">
            {!selected ? <div className="messaging-empty"><span>OP</span><h2>Choose a conversation.</h2><p>Your private and team conversations will appear here.</p></div> : <>
              <header className="messaging-thread-header">
                <div><small>{selected.kind==="team"?"TEAM GROUP":selected.kind==="support"?"PRIVATE ADMIN SUPPORT":selected.kind==="announcement"?"ADMIN BROADCAST":"PRIVATE MESSAGE"}</small><h2>{selected.kind==="direct"?(selected.other_participant_name??"Direct conversation"):selected.title}</h2></div>
                {selected.kind==="direct"&&selected.other_participant_user_id&&<button type="button" className="messaging-block-button" disabled={busy} onClick={()=>void blockParticipant()}>BLOCK MEMBER</button>}
              </header>
              <div className="messaging-message-list" aria-live="polite">
                {hasMoreMessages&&<button type="button" className="messaging-load-older" disabled={olderLoading} onClick={()=>void loadOlderMessages()}>{olderLoading?"LOADING…":"LOAD OLDER MESSAGES"}</button>}
                {threadLoading ? <p className="form-note">Loading conversation…</p> : messages.map((message) => <article key={message.message_id} className={message.sender_id===userId?"messaging-message mine":"messaging-message"}>
                  <div className="messaging-message-meta"><strong>{message.sender_id===userId?"YOU":message.sender_name}</strong><time>{new Date(message.created_at).toLocaleString("en-GB",{dateStyle:"medium",timeStyle:"short"})}</time>{message.message_type==="announcement"&&<b>ANNOUNCEMENT</b>}</div>
                  <p>{message.body}</p>
                  {message.sender_id===userId&&message.message_id===selected.last_message_id&&selected.kind==="direct"&&selected.other_participant_last_read_at&&new Date(selected.other_participant_last_read_at).getTime()>=new Date(message.created_at).getTime()&&<small className="messaging-read-receipt">SEEN</small>}
                  {message.sender_id===userId&&message.message_id===selected.last_message_id&&selected.kind!=="direct"&&selected.read_by_count>0&&<small className="messaging-read-receipt">READ BY {selected.read_by_count}/{Math.max(0,selected.participant_count-1)}</small>}
                  {!message.is_hidden&&message.sender_id!==userId&&<div className="messaging-report"><button type="button" onClick={()=>{setReportingId(reportingId===message.message_id?"":message.message_id);setReportReason("");}}>REPORT</button>{reportingId===message.message_id&&<div><textarea rows={2} value={reportReason} onChange={(event)=>setReportReason(event.target.value)} placeholder="Why are you reporting this message?"/><button type="button" disabled={busy} onClick={()=>void reportMessage(message.message_id)}>SEND REPORT</button></div>}</div>}
                </article>)}
                {!threadLoading&&messages.length===0&&<p className="form-note">This conversation is ready. Send the first message.</p>}
              </div>
              {selected.kind!=="announcement"&&<form className="messaging-composer" onSubmit={sendMessage}>
                {canAnnounce&&<label className="messaging-announcement-toggle"><input type="checkbox" checked={announcement} onChange={(event)=>setAnnouncement(event.target.checked)}/> Post as a team announcement</label>}
                <textarea value={composer} onChange={(event)=>setComposer(event.target.value)} maxLength={2000} rows={3} placeholder="Write a message…" required/>
                <div><small>{composer.length}/2000</small><button type="submit" disabled={busy||!composer.trim()}>{busy?"SENDING…":"SEND MESSAGE"}</button></div>
              </form>}
            </>}
          </section>
        </div>
      </section>
    </main>
  );
}
