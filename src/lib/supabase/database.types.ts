export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      admin_context_preferences: {
        Row: {
          league_id: string | null
          location_id: string | null
          season_id: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          league_id?: string | null
          location_id?: string | null
          season_id?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          league_id?: string | null
          location_id?: string | null
          season_id?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "admin_context_preferences_league_id_fkey"
            columns: ["league_id"]
            isOneToOne: false
            referencedRelation: "leagues"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admin_context_preferences_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admin_context_preferences_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_log: {
        Row: {
          action: string
          actor_user_id: string | null
          after_data: Json | null
          before_data: Json | null
          created_at: string
          entity_id: string | null
          entity_type: string
          id: number
          reason: string | null
        }
        Insert: {
          action: string
          actor_user_id?: string | null
          after_data?: Json | null
          before_data?: Json | null
          created_at?: string
          entity_id?: string | null
          entity_type: string
          id?: never
          reason?: string | null
        }
        Update: {
          action?: string
          actor_user_id?: string | null
          after_data?: Json | null
          before_data?: Json | null
          created_at?: string
          entity_id?: string | null
          entity_type?: string
          id?: never
          reason?: string | null
        }
        Relationships: []
      }
      finance_entries: {
        Row: {
          amount_pence: number
          created_at: string
          created_by: string | null
          description: string
          due_at: string | null
          entry_type: string
          fixture_id: string | null
          id: string
          notes: string | null
          occurred_at: string
          payment_method: string | null
          reference: string | null
          season_team_id: string
        }
        Insert: {
          amount_pence: number
          created_at?: string
          created_by?: string | null
          description: string
          due_at?: string | null
          entry_type: string
          fixture_id?: string | null
          id?: string
          notes?: string | null
          occurred_at?: string
          payment_method?: string | null
          reference?: string | null
          season_team_id: string
        }
        Update: {
          amount_pence?: number
          created_at?: string
          created_by?: string | null
          description?: string
          due_at?: string | null
          entry_type?: string
          fixture_id?: string | null
          id?: string
          notes?: string | null
          occurred_at?: string
          payment_method?: string | null
          reference?: string | null
          season_team_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "finance_entries_fixture_id_fkey"
            columns: ["fixture_id"]
            isOneToOne: false
            referencedRelation: "fixtures"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_entries_season_team_id_fkey"
            columns: ["season_team_id"]
            isOneToOne: false
            referencedRelation: "season_teams"
            referencedColumns: ["id"]
          },
        ]
      }
      competition_player_identities: {
        Row: {
          anonymised_at: string | null
          counts_for_statistics: boolean
          created_at: string
          display_name: string
          id: string
        }
        Insert: {
          anonymised_at?: string | null
          counts_for_statistics?: boolean
          created_at?: string
          display_name: string
          id?: string
        }
        Update: {
          anonymised_at?: string | null
          counts_for_statistics?: boolean
          created_at?: string
          display_name?: string
          id?: string
        }
        Relationships: []
      }
      finance_operating_costs: {
        Row: {
          amount_pence: number
          category: string
          created_at: string
          created_by: string | null
          description: string
          id: string
          league_id: string | null
          location_id: string | null
          notes: string | null
          occurred_at: string
          reference: string | null
          season_id: string | null
        }
        Insert: {
          amount_pence: number
          category: string
          created_at?: string
          created_by?: string | null
          description: string
          id?: string
          league_id?: string | null
          location_id?: string | null
          notes?: string | null
          occurred_at?: string
          reference?: string | null
          season_id?: string | null
        }
        Update: {
          amount_pence?: number
          category?: string
          created_at?: string
          created_by?: string | null
          description?: string
          id?: string
          league_id?: string | null
          location_id?: string | null
          notes?: string | null
          occurred_at?: string
          reference?: string | null
          season_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "finance_operating_costs_league_id_fkey"
            columns: ["league_id"]
            isOneToOne: false
            referencedRelation: "leagues"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_operating_costs_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_operating_costs_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
        ]
      }
      fixture_availability: {
        Row: {
          fixture_id: string
          id: string
          is_available: boolean
          responded_at: string
          response_note: string | null
          user_id: string
        }
        Insert: {
          fixture_id: string
          id?: string
          is_available: boolean
          responded_at?: string
          response_note?: string | null
          user_id: string
        }
        Update: {
          fixture_id?: string
          id?: string
          is_available?: boolean
          responded_at?: string
          response_note?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fixture_availability_fixture_id_fkey"
            columns: ["fixture_id"]
            isOneToOne: false
            referencedRelation: "fixtures"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fixture_availability_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      fixture_goal_records: {
        Row: {
          competition_player_id: string
          created_at: string
          created_by: string | null
          fixture_id: string
          id: string
          scorer_user_id: string | null
          season_team_id: string
          void_reason: string | null
          voided_at: string | null
          voided_by: string | null
          assist_competition_player_id: string | null
          is_own_goal: boolean
        }
        Insert: {
          competition_player_id?: string
          created_at?: string
          created_by?: string | null
          fixture_id: string
          id?: string
          scorer_user_id?: string | null
          season_team_id: string
          void_reason?: string | null
          voided_at?: string | null
          voided_by?: string | null
          assist_competition_player_id?: string | null
          is_own_goal?: boolean
        }
        Update: {
          competition_player_id?: string
          created_at?: string
          created_by?: string | null
          fixture_id?: string
          id?: string
          scorer_user_id?: string | null
          season_team_id?: string
          void_reason?: string | null
          voided_at?: string | null
          voided_by?: string | null
          assist_competition_player_id?: string | null
          is_own_goal?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "fixture_goal_records_competition_player_id_fkey"
            columns: ["competition_player_id"]
            isOneToOne: false
            referencedRelation: "competition_player_identities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fixture_goal_records_fixture_id_fkey"
            columns: ["fixture_id"]
            isOneToOne: false
            referencedRelation: "fixtures"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fixture_goal_records_scorer_user_id_set_null_fkey"
            columns: ["scorer_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fixture_goal_records_season_team_id_fkey"
            columns: ["season_team_id"]
            isOneToOne: false
            referencedRelation: "season_teams"
            referencedColumns: ["id"]
          },
        ]
      }
      fixture_motm_nominations: {
        Row: {
          competition_player_id: string
          corrected_at: string | null
          corrected_by: string | null
          correction_reason: string | null
          fixture_id: string
          id: string
          nominated_at: string
          nominated_by: string
          season_team_id: string
        }
        Insert: {
          competition_player_id: string
          corrected_at?: string | null
          corrected_by?: string | null
          correction_reason?: string | null
          fixture_id: string
          id?: string
          nominated_at?: string
          nominated_by: string
          season_team_id: string
        }
        Update: {
          competition_player_id?: string
          corrected_at?: string | null
          corrected_by?: string | null
          correction_reason?: string | null
          fixture_id?: string
          id?: string
          nominated_at?: string
          nominated_by?: string
          season_team_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fixture_motm_nominations_competition_player_id_fkey"
            columns: ["competition_player_id"]
            isOneToOne: false
            referencedRelation: "competition_player_identities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fixture_motm_nominations_fixture_id_fkey"
            columns: ["fixture_id"]
            isOneToOne: false
            referencedRelation: "fixtures"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fixture_motm_nominations_season_team_id_fkey"
            columns: ["season_team_id"]
            isOneToOne: false
            referencedRelation: "season_teams"
            referencedColumns: ["id"]
          },
        ]
      }
      fixture_results: {
        Row: {
          away_score: number
          confirmed_at: string | null
          confirmed_by: string | null
          fixture_id: string
          home_score: number
          updated_at: string
        }
        Insert: {
          away_score: number
          confirmed_at?: string | null
          confirmed_by?: string | null
          fixture_id: string
          home_score: number
          updated_at?: string
        }
        Update: {
          away_score?: number
          confirmed_at?: string | null
          confirmed_by?: string | null
          fixture_id?: string
          home_score?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fixture_results_fixture_id_fkey"
            columns: ["fixture_id"]
            isOneToOne: true
            referencedRelation: "fixtures"
            referencedColumns: ["id"]
          },
        ]
      }
      fixture_team_sheet_players: {
        Row: {
          competition_player_id: string
          created_at: string
          did_appear: boolean
          id: string
          is_goalkeeper: boolean
          role: Database["public"]["Enums"]["lineup_role"]
          squad_number_snapshot: number | null
          team_sheet_id: string
          user_id: string | null
        }
        Insert: {
          competition_player_id?: string
          created_at?: string
          did_appear?: boolean
          id?: string
          is_goalkeeper?: boolean
          role: Database["public"]["Enums"]["lineup_role"]
          squad_number_snapshot?: number | null
          team_sheet_id: string
          user_id?: string | null
        }
        Update: {
          competition_player_id?: string
          created_at?: string
          did_appear?: boolean
          id?: string
          is_goalkeeper?: boolean
          role?: Database["public"]["Enums"]["lineup_role"]
          squad_number_snapshot?: number | null
          team_sheet_id?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fixture_team_sheet_players_competition_player_id_fkey"
            columns: ["competition_player_id"]
            isOneToOne: false
            referencedRelation: "competition_player_identities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fixture_team_sheet_players_team_sheet_id_fkey"
            columns: ["team_sheet_id"]
            isOneToOne: false
            referencedRelation: "fixture_team_sheets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fixture_team_sheet_players_user_id_set_null_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      fixture_team_sheets: {
        Row: {
          draft_saved_at: string | null
          fixture_id: string
          id: string
          is_locked: boolean
          season_team_id: string
          submitted_at: string | null
          submitted_by: string | null
        }
        Insert: {
          draft_saved_at?: string | null
          fixture_id: string
          id?: string
          is_locked?: boolean
          season_team_id: string
          submitted_at?: string | null
          submitted_by?: string | null
        }
        Update: {
          draft_saved_at?: string | null
          fixture_id?: string
          id?: string
          is_locked?: boolean
          season_team_id?: string
          submitted_at?: string | null
          submitted_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fixture_team_sheets_fixture_id_fkey"
            columns: ["fixture_id"]
            isOneToOne: false
            referencedRelation: "fixtures"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fixture_team_sheets_season_team_id_fkey"
            columns: ["season_team_id"]
            isOneToOne: false
            referencedRelation: "season_teams"
            referencedColumns: ["id"]
          },
        ]
      }
      fixtures: {
        Row: {
          gameweek_id: string | null
          away_team_id: string
          created_at: string
          fixture_number: number
          gameweek: number
          home_team_id: string
          id: string
          notes: string | null
          scheduled_at: string | null
          season_id: string
          status: Database["public"]["Enums"]["fixture_status"]
          updated_at: string
          venue_id: string | null
          is_title_final: boolean
        }
        Insert: {
          gameweek_id?: string | null
          away_team_id: string
          created_at?: string
          fixture_number?: number
          gameweek: number
          home_team_id: string
          id?: string
          notes?: string | null
          scheduled_at?: string | null
          season_id: string
          status?: Database["public"]["Enums"]["fixture_status"]
          updated_at?: string
          venue_id?: string | null
          is_title_final?: boolean
        }
        Update: {
          gameweek_id?: string | null
          away_team_id?: string
          created_at?: string
          fixture_number?: number
          gameweek?: number
          home_team_id?: string
          id?: string
          notes?: string | null
          scheduled_at?: string | null
          season_id?: string
          status?: Database["public"]["Enums"]["fixture_status"]
          updated_at?: string
          venue_id?: string | null
          is_title_final?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "fixtures_away_team_id_fkey"
            columns: ["away_team_id"]
            isOneToOne: false
            referencedRelation: "season_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fixtures_home_team_id_fkey"
            columns: ["home_team_id"]
            isOneToOne: false
            referencedRelation: "season_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fixtures_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fixtures_venue_id_fkey"
            columns: ["venue_id"]
            isOneToOne: false
            referencedRelation: "venues"
            referencedColumns: ["id"]
          },
        ]
      }
      gallery_items: {
        Row: {
          caption: string
          created_at: string
          id: string
          is_published: boolean
          location_id: string
          object_path: string
          published_at: string | null
          uploaded_by: string | null
        }
        Insert: {
          caption?: string
          created_at?: string
          id?: string
          is_published?: boolean
          location_id: string
          object_path: string
          published_at?: string | null
          uploaded_by?: string | null
        }
        Update: {
          caption?: string
          created_at?: string
          id?: string
          is_published?: boolean
          location_id?: string
          object_path?: string
          published_at?: string | null
          uploaded_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "gallery_items_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["id"]
          },
        ]
      }
      gameweek_postponement_history: {
        Row: {
          actor_user_id: string
          affected_fixtures: number
          after_data: Json
          before_data: Json
          created_at: string
          credited_unpaid_obligations: number
          gameweek_id: string
          id: string
          new_scheduled_at: string
          new_week_number: number
          old_scheduled_at: string
          old_week_number: number
          reason: string
          refunded_team_payments: number
          season_id: string
        }
        Insert: {
          actor_user_id: string
          affected_fixtures: number
          after_data?: Json
          before_data?: Json
          created_at?: string
          credited_unpaid_obligations?: number
          gameweek_id: string
          id?: string
          new_scheduled_at: string
          new_week_number: number
          old_scheduled_at: string
          old_week_number: number
          reason: string
          refunded_team_payments?: number
          season_id: string
        }
        Update: {
          actor_user_id?: string
          affected_fixtures?: number
          after_data?: Json
          before_data?: Json
          created_at?: string
          credited_unpaid_obligations?: number
          gameweek_id?: string
          id?: string
          new_scheduled_at?: string
          new_week_number?: number
          old_scheduled_at?: string
          old_week_number?: number
          reason?: string
          refunded_team_payments?: number
          season_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "gameweek_postponement_history_gameweek_id_fkey"
            columns: ["gameweek_id"]
            isOneToOne: false
            referencedRelation: "season_gameweeks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "gameweek_postponement_history_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
        ]
      }
      leagues: {
        Row: {
          created_at: string
          description: string | null
          format: Database["public"]["Enums"]["competition_format"]
          id: string
          is_published: boolean
          location_id: string
          name: string
          slug: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          format?: Database["public"]["Enums"]["competition_format"]
          id?: string
          is_published?: boolean
          location_id: string
          name: string
          slug: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          format?: Database["public"]["Enums"]["competition_format"]
          id?: string
          is_published?: boolean
          location_id?: string
          name?: string
          slug?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "leagues_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["id"]
          },
        ]
      }
      location_admin_assignments: {
        Row: {
          assigned_by: string | null
          created_at: string
          id: string
          location_id: string
          user_id: string
        }
        Insert: {
          assigned_by?: string | null
          created_at?: string
          id?: string
          location_id: string
          user_id: string
        }
        Update: {
          assigned_by?: string | null
          created_at?: string
          id?: string
          location_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "location_admin_assignments_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["id"]
          },
        ]
      }
      locations: {
        Row: {
          address: string | null
          created_at: string
          id: string
          is_active: boolean
          name: string
          region: string
          slug: string
          town: string
          updated_at: string
        }
        Insert: {
          address?: string | null
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          region?: string
          slug: string
          town: string
          updated_at?: string
        }
        Update: {
          address?: string | null
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          region?: string
          slug?: string
          town?: string
          updated_at?: string
        }
        Relationships: []
      }
      message_conversation_participants: {
        Row: {
          conversation_id: string
          joined_at: string
          last_read_at: string
          left_at: string | null
          user_id: string
        }
        Insert: {
          conversation_id: string
          joined_at?: string
          last_read_at?: string
          left_at?: string | null
          user_id: string
        }
        Update: {
          conversation_id?: string
          joined_at?: string
          last_read_at?: string
          left_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "message_conversation_participants_conversation_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "message_conversations"
            referencedColumns: ["id"]
          },
        ]
      }
      message_conversations: {
        Row: {
          closed_at: string | null
          created_at: string
          created_by: string | null
          direct_pair_key: string | null
          id: string
          kind: string
          location_id: string | null
          season_id: string | null
          season_team_id: string | null
          target_id: string | null
          target_type: string | null
          title: string
          updated_at: string
        }
        Insert: {
          closed_at?: string | null
          created_at?: string
          created_by?: string | null
          direct_pair_key?: string | null
          id?: string
          kind: string
          location_id?: string | null
          season_id?: string | null
          season_team_id?: string | null
          target_id?: string | null
          target_type?: string | null
          title: string
          updated_at?: string
        }
        Update: {
          closed_at?: string | null
          created_at?: string
          created_by?: string | null
          direct_pair_key?: string | null
          id?: string
          kind?: string
          location_id?: string | null
          season_id?: string | null
          season_team_id?: string | null
          target_id?: string | null
          target_type?: string | null
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "message_conversations_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "message_conversations_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "message_conversations_season_team_id_fkey"
            columns: ["season_team_id"]
            isOneToOne: true
            referencedRelation: "season_teams"
            referencedColumns: ["id"]
          },
        ]
      }
      message_reports: {
        Row: {
          conversation_id: string | null
          created_at: string
          id: string
          message_id: string | null
          reason: string
          reported_user_id: string | null
          reporter_id: string | null
          resolution_action: string | null
          resolution_reason: string | null
          resolved_at: string | null
          resolved_by: string | null
          status: string
        }
        Insert: {
          conversation_id?: string | null
          created_at?: string
          id?: string
          message_id?: string | null
          reason: string
          reported_user_id?: string | null
          reporter_id?: string | null
          resolution_action?: string | null
          resolution_reason?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          status?: string
        }
        Update: {
          conversation_id?: string | null
          created_at?: string
          id?: string
          message_id?: string | null
          reason?: string
          reported_user_id?: string | null
          reporter_id?: string | null
          resolution_action?: string | null
          resolution_reason?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "message_reports_conversation_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "message_conversations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "message_reports_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
        ]
      }
      message_user_blocks: {
        Row: {
          blocked_user_id: string
          blocker_id: string
          created_at: string
        }
        Insert: {
          blocked_user_id: string
          blocker_id: string
          created_at?: string
        }
        Update: {
          blocked_user_id?: string
          blocker_id?: string
          created_at?: string
        }
        Relationships: [
        ]
      }
      messages: {
        Row: {
          body: string
          conversation_id: string
          created_at: string
          hidden_at: string | null
          hidden_by: string | null
          hidden_reason: string | null
          id: string
          is_hidden: boolean
          message_type: string
          sender_id: string | null
        }
        Insert: {
          body: string
          conversation_id: string
          created_at?: string
          hidden_at?: string | null
          hidden_by?: string | null
          hidden_reason?: string | null
          id?: string
          is_hidden?: boolean
          message_type?: string
          sender_id?: string | null
        }
        Update: {
          body?: string
          conversation_id?: string
          created_at?: string
          hidden_at?: string | null
          hidden_by?: string | null
          hidden_reason?: string | null
          id?: string
          is_hidden?: boolean
          message_type?: string
          sender_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "messages_conversation_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "message_conversations"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_dispatch_settings: {
        Row: {
          enabled: boolean
          id: boolean
          reason: string | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          enabled?: boolean
          id?: boolean
          reason?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          enabled?: boolean
          id?: boolean
          reason?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: []
      }
      notification_events: {
        Row: {
          attempt_count: number
          channel: string
          created_at: string
          dedupe_key: string | null
          event_type: string
          held_at: string | null
          held_by: string | null
          hold_reason: string | null
          id: string
          last_attempt_at: string | null
          last_error: string | null
          locked_at: string | null
          manual_retry_used: boolean
          next_attempt_at: string
          payload: Json
          provider_reference: string | null
          read_at: string | null
          sent_at: string | null
          status: string
          unconfirmed_at: string | null
          updated_at: string
          user_id: string | null
        }
        Insert: {
          attempt_count?: number
          channel: string
          created_at?: string
          dedupe_key?: string | null
          event_type: string
          held_at?: string | null
          held_by?: string | null
          hold_reason?: string | null
          id?: string
          last_attempt_at?: string | null
          last_error?: string | null
          locked_at?: string | null
          manual_retry_used?: boolean
          next_attempt_at?: string
          payload?: Json
          provider_reference?: string | null
          read_at?: string | null
          sent_at?: string | null
          status?: string
          unconfirmed_at?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          attempt_count?: number
          channel?: string
          created_at?: string
          dedupe_key?: string | null
          event_type?: string
          held_at?: string | null
          held_by?: string | null
          hold_reason?: string | null
          id?: string
          last_attempt_at?: string | null
          last_error?: string | null
          locked_at?: string | null
          manual_retry_used?: boolean
          next_attempt_at?: string
          payload?: Json
          provider_reference?: string | null
          read_at?: string | null
          sent_at?: string | null
          status?: string
          unconfirmed_at?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "notification_events_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_preferences: {
        Row: {
          email_enabled: boolean
          in_app_enabled: boolean
          sms_consent_revoked_at: string | null
          sms_consent_version: string | null
          sms_consented_at: string | null
          sms_enabled: boolean
          updated_at: string
          user_id: string
        }
        Insert: {
          email_enabled?: boolean
          in_app_enabled?: boolean
          sms_consent_revoked_at?: string | null
          sms_consent_version?: string | null
          sms_consented_at?: string | null
          sms_enabled?: boolean
          updated_at?: string
          user_id: string
        }
        Update: {
          email_enabled?: boolean
          in_app_enabled?: boolean
          sms_consent_revoked_at?: string | null
          sms_consent_version?: string | null
          sms_consented_at?: string | null
          sms_enabled?: boolean
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_preferences_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      payment_records: {
        Row: {
          amount_pence: number
          amount_refunded_pence: number
          checkout_attempt: number
          created_at: string
          currency: string
          fee_snapshot: Json
          fixture_id: string | null
          id: string
          last_stripe_event_at: string | null
          net_amount_pence: number | null
          paid_at: string | null
          player_user_id: string | null
          refunded_at: string | null
          season_team_id: string
          status: Database["public"]["Enums"]["payment_status"]
          stripe_checkout_session_id: string | null
          stripe_customer_id: string | null
          stripe_fee_pence: number | null
          stripe_payment_intent_id: string | null
          updated_at: string
        }
        Insert: {
          amount_pence: number
          amount_refunded_pence?: number
          checkout_attempt?: number
          created_at?: string
          currency?: string
          fee_snapshot: Json
          fixture_id?: string | null
          id?: string
          last_stripe_event_at?: string | null
          net_amount_pence?: number | null
          paid_at?: string | null
          player_user_id?: string | null
          refunded_at?: string | null
          season_team_id: string
          status?: Database["public"]["Enums"]["payment_status"]
          stripe_checkout_session_id?: string | null
          stripe_customer_id?: string | null
          stripe_fee_pence?: number | null
          stripe_payment_intent_id?: string | null
          updated_at?: string
        }
        Update: {
          amount_pence?: number
          amount_refunded_pence?: number
          checkout_attempt?: number
          created_at?: string
          currency?: string
          fee_snapshot?: Json
          fixture_id?: string | null
          id?: string
          last_stripe_event_at?: string | null
          net_amount_pence?: number | null
          paid_at?: string | null
          player_user_id?: string | null
          refunded_at?: string | null
          season_team_id?: string
          status?: Database["public"]["Enums"]["payment_status"]
          stripe_checkout_session_id?: string | null
          stripe_customer_id?: string | null
          stripe_fee_pence?: number | null
          stripe_payment_intent_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "payment_records_fixture_id_fkey"
            columns: ["fixture_id"]
            isOneToOne: false
            referencedRelation: "fixtures"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payment_records_season_team_id_fkey"
            columns: ["season_team_id"]
            isOneToOne: false
            referencedRelation: "season_teams"
            referencedColumns: ["id"]
          },
        ]
      }
      player_account_inactivity_warnings: {
        Row: {
          claimed_at: string
          created_at: string
          inactivity_started_at: string
          sent_at: string | null
          status: string
          user_id: string
          warning_days: number
        }
        Insert: {
          claimed_at?: string
          created_at?: string
          inactivity_started_at: string
          sent_at?: string | null
          status?: string
          user_id: string
          warning_days: number
        }
        Update: {
          claimed_at?: string
          created_at?: string
          inactivity_started_at?: string
          sent_at?: string | null
          status?: string
          user_id?: string
          warning_days?: number
        }
        Relationships: [
          {
            foreignKeyName: "player_account_inactivity_warnings_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      player_guardian_consents: {
        Row: {
          created_at: string
          guardian_email: string
          guardian_full_name: string
          id: string
          player_date_of_birth: string
          player_user_id: string
          requested_at: string
          review_reason: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: string
          updated_at: string
          verification_expires_at: string | null
          verification_token_hash: string | null
          verified_at: string | null
          withdrawal_token_expires_at: string | null
          withdrawal_token_hash: string | null
          withdrawn_at: string | null
        }
        Insert: {
          created_at?: string
          guardian_email: string
          guardian_full_name: string
          id?: string
          player_date_of_birth: string
          player_user_id: string
          requested_at?: string
          review_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          updated_at?: string
          verification_expires_at?: string | null
          verification_token_hash?: string | null
          verified_at?: string | null
          withdrawal_token_expires_at?: string | null
          withdrawal_token_hash?: string | null
          withdrawn_at?: string | null
        }
        Update: {
          created_at?: string
          guardian_email?: string
          guardian_full_name?: string
          id?: string
          player_date_of_birth?: string
          player_user_id?: string
          requested_at?: string
          review_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          updated_at?: string
          verification_expires_at?: string | null
          verification_token_hash?: string | null
          verified_at?: string | null
          withdrawal_token_expires_at?: string | null
          withdrawal_token_hash?: string | null
          withdrawn_at?: string | null
        }
        Relationships: [
        ]
      }
      player_registration_reviews: {
        Row: {
          match_evidence: Json
          created_at: string
          email_matched: boolean
          id: string
          matched_player_ids: string[]
          name_matched: boolean
          phone_matched: boolean
          player_id: string
          review_reason: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: string
        }
        Insert: {
          match_evidence?: Json
          created_at?: string
          email_matched: boolean
          id?: string
          matched_player_ids?: string[]
          name_matched: boolean
          phone_matched: boolean
          player_id: string
          review_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
        }
        Update: {
          match_evidence?: Json
          created_at?: string
          email_matched?: boolean
          id?: string
          matched_player_ids?: string[]
          name_matched?: boolean
          phone_matched?: boolean
          player_id?: string
          review_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "player_registration_reviews_player_id_fkey"
            columns: ["player_id"]
            isOneToOne: true
            referencedRelation: "players"
            referencedColumns: ["id"]
          },
        ]
      }
      player_transfer_requests: {
        Row: {
          created_at: string
          destination_season_team_id: string
          id: string
          is_emergency: boolean
          league_id: string
          reason: string
          requested_at: string
          resolution_reason: string | null
          resolved_at: string | null
          resolved_by: string | null
          source_membership_id: string | null
          source_season_team_id: string
          status: string
          target_fixture_id: string | null
          updated_at: string
          user_id: string | null
        }
        Insert: {
          created_at?: string
          destination_season_team_id: string
          id?: string
          is_emergency?: boolean
          league_id: string
          reason: string
          requested_at?: string
          resolution_reason?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          source_membership_id?: string | null
          source_season_team_id: string
          status?: string
          target_fixture_id?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          created_at?: string
          destination_season_team_id?: string
          id?: string
          is_emergency?: boolean
          league_id?: string
          reason?: string
          requested_at?: string
          resolution_reason?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          source_membership_id?: string | null
          source_season_team_id?: string
          status?: string
          target_fixture_id?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "player_transfer_requests_destination_season_team_id_fkey"
            columns: ["destination_season_team_id"]
            isOneToOne: false
            referencedRelation: "season_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "player_transfer_requests_source_membership_set_null_fkey"
            columns: ["source_membership_id"]
            isOneToOne: false
            referencedRelation: "team_memberships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "player_transfer_requests_source_season_team_id_fkey"
            columns: ["source_season_team_id"]
            isOneToOne: false
            referencedRelation: "season_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "player_transfer_requests_user_id_set_null_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      platform_feature_flags: {
        Row: {
          enabled: boolean
          feature_key: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          enabled: boolean
          feature_key: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          enabled?: boolean
          feature_key?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: []
      }
      players: {
        Row: {
          guardian_consent_previous_status: Database["public"]["Enums"]["player_registration_status"] | null
          banned_at: string | null
          banned_reason: string | null
          created_at: string
          competition_player_id: string
          date_of_birth: string
          disciplinary_inactive: boolean
          disciplinary_strikes: number
          email: string
          full_name: string
          id: string
          is_banned: boolean
          is_genuine: boolean
          phone: string
          registration_status: Database["public"]["Enums"]["player_registration_status"]
          updated_at: string
          user_id: string
        }
        Insert: {
          guardian_consent_previous_status?: Database["public"]["Enums"]["player_registration_status"] | null
          banned_at?: string | null
          banned_reason?: string | null
          created_at?: string
          competition_player_id?: string
          date_of_birth: string
          disciplinary_inactive?: boolean
          disciplinary_strikes?: number
          email: string
          full_name: string
          id?: string
          is_banned?: boolean
          is_genuine?: boolean
          phone: string
          registration_status: Database["public"]["Enums"]["player_registration_status"]
          updated_at?: string
          user_id: string
        }
        Update: {
          guardian_consent_previous_status?: Database["public"]["Enums"]["player_registration_status"] | null
          banned_at?: string | null
          banned_reason?: string | null
          created_at?: string
          competition_player_id?: string
          date_of_birth?: string
          disciplinary_inactive?: boolean
          disciplinary_strikes?: number
          email?: string
          full_name?: string
          id?: string
          is_banned?: boolean
          is_genuine?: boolean
          phone?: string
          registration_status?: Database["public"]["Enums"]["player_registration_status"]
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "players_competition_player_id_fkey"
            columns: ["competition_player_id"]
            isOneToOne: true
            referencedRelation: "competition_player_identities"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          account_closed_at: string | null
          account_retention_status: string
          archive_expires_at: string | null
          avatar_path: string | null
          created_at: string
          date_of_birth: string | null
          display_name: string | null
          emergency_contact_name: string | null
          emergency_contact_phone: string | null
          first_name: string | null
          id: string
          last_name: string | null
          last_sign_in_at: string
          phone: string | null
          preferred_position: string | null
          reactivation_requested_at: string | null
          reactivation_token_expires_at: string | null
          reactivation_token_hash: string | null
          retention_hold: boolean
          retention_hold_reason: string | null
          updated_at: string
        }
        Insert: {
          account_closed_at?: string | null
          account_retention_status?: string
          archive_expires_at?: string | null
          avatar_path?: string | null
          created_at?: string
          date_of_birth?: string | null
          display_name?: string | null
          emergency_contact_name?: string | null
          emergency_contact_phone?: string | null
          first_name?: string | null
          id: string
          last_name?: string | null
          last_sign_in_at?: string
          phone?: string | null
          preferred_position?: string | null
          reactivation_requested_at?: string | null
          reactivation_token_expires_at?: string | null
          reactivation_token_hash?: string | null
          retention_hold?: boolean
          retention_hold_reason?: string | null
          updated_at?: string
        }
        Update: {
          account_closed_at?: string | null
          account_retention_status?: string
          archive_expires_at?: string | null
          avatar_path?: string | null
          created_at?: string
          date_of_birth?: string | null
          display_name?: string | null
          emergency_contact_name?: string | null
          emergency_contact_phone?: string | null
          first_name?: string | null
          id?: string
          last_name?: string | null
          last_sign_in_at?: string
          phone?: string | null
          preferred_position?: string | null
          reactivation_requested_at?: string | null
          reactivation_token_expires_at?: string | null
          reactivation_token_hash?: string | null
          retention_hold?: boolean
          retention_hold_reason?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      referee_applications: {
        Row: {
          additional_notes: string | null
          availability: Json
          contact_phone: string
          created_at: string
          experience_summary: string
          id: string
          preferred_location_ids: string[]
          qualifications: string[]
          review_reason: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: string
          submitted_at: string
          updated_at: string
          user_id: string
        }
        Insert: {
          additional_notes?: string | null
          availability: Json
          contact_phone: string
          created_at?: string
          experience_summary: string
          id?: string
          preferred_location_ids: string[]
          qualifications?: string[]
          review_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          submitted_at?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          additional_notes?: string | null
          availability?: Json
          contact_phone?: string
          created_at?: string
          experience_summary?: string
          id?: string
          preferred_location_ids?: string[]
          qualifications?: string[]
          review_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          submitted_at?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
        ]
      }
      referee_connect_accounts: {
        Row: {
          charges_enabled: boolean
          created_at: string
          details_submitted: boolean
          disabled_reason: string | null
          last_synced_at: string
          onboarding_status: string
          payouts_enabled: boolean
          referee_user_id: string
          requirements_due: Json
          stripe_account_id: string
          stripe_event_created_at: string
          transfers_enabled: boolean
          updated_at: string
        }
        Insert: {
          charges_enabled?: boolean
          created_at?: string
          details_submitted?: boolean
          disabled_reason?: string | null
          last_synced_at?: string
          onboarding_status?: string
          payouts_enabled?: boolean
          referee_user_id: string
          requirements_due?: Json
          stripe_account_id: string
          stripe_event_created_at?: string
          transfers_enabled?: boolean
          updated_at?: string
        }
        Update: {
          charges_enabled?: boolean
          created_at?: string
          details_submitted?: boolean
          disabled_reason?: string | null
          last_synced_at?: string
          onboarding_status?: string
          payouts_enabled?: boolean
          referee_user_id?: string
          requirements_due?: Json
          stripe_account_id?: string
          stripe_event_created_at?: string
          transfers_enabled?: boolean
          updated_at?: string
        }
        Relationships: [
        ]
      }
      referee_connect_webhook_events: {
        Row: {
          created_at: string
          event_type: string
          processed_at: string | null
          stripe_event_id: string
        }
        Insert: {
          created_at?: string
          event_type: string
          processed_at?: string | null
          stripe_event_id: string
        }
        Update: {
          created_at?: string
          event_type?: string
          processed_at?: string | null
          stripe_event_id?: string
        }
        Relationships: [
        ]
      }
      referee_disciplinary_events: {
        Row: {
          card_type: string
          competition_player_id: string | null
          created_at: string
          created_by: string | null
          description: string | null
          event_index: number
          finance_entry_id: string | null
          fine_amount_pence: number
          fixture_id: string
          id: string
          minute: number | null
          recipient_type: string
          report_id: string
          season_team_id: string
          strike_applied: boolean
          void_reason: string | null
          voided_at: string | null
          voided_by: string | null
        }
        Insert: {
          card_type: string
          competition_player_id?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          event_index: number
          finance_entry_id?: string | null
          fine_amount_pence: number
          fixture_id: string
          id?: string
          minute?: number | null
          recipient_type: string
          report_id: string
          season_team_id: string
          strike_applied?: boolean
          void_reason?: string | null
          voided_at?: string | null
          voided_by?: string | null
        }
        Update: {
          card_type?: string
          competition_player_id?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          event_index?: number
          finance_entry_id?: string | null
          fine_amount_pence?: number
          fixture_id?: string
          id?: string
          minute?: number | null
          recipient_type?: string
          report_id?: string
          season_team_id?: string
          strike_applied?: boolean
          void_reason?: string | null
          voided_at?: string | null
          voided_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "referee_disciplinary_events_competition_player_id_fkey"
            columns: ["competition_player_id"]
            isOneToOne: false
            referencedRelation: "competition_player_identities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referee_disciplinary_events_finance_entry_id_fkey"
            columns: ["finance_entry_id"]
            isOneToOne: false
            referencedRelation: "finance_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referee_disciplinary_events_fixture_id_fkey"
            columns: ["fixture_id"]
            isOneToOne: false
            referencedRelation: "fixtures"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referee_disciplinary_events_report_id_fkey"
            columns: ["report_id"]
            isOneToOne: false
            referencedRelation: "referee_match_reports"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referee_disciplinary_events_season_team_id_fkey"
            columns: ["season_team_id"]
            isOneToOne: false
            referencedRelation: "season_teams"
            referencedColumns: ["id"]
          },
        ]
      }
      referee_fixture_assignments: {
        Row: {
          assigned_at: string
          assigned_by: string
          assignment_role: string
          cancellation_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          fixture_id: string
          id: string
          referee_user_id: string
        }
        Insert: {
          assigned_at?: string
          assigned_by: string
          assignment_role: string
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          fixture_id: string
          id?: string
          referee_user_id: string
        }
        Update: {
          assigned_at?: string
          assigned_by?: string
          assignment_role?: string
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          fixture_id?: string
          id?: string
          referee_user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "referee_fixture_assignments_fixture_id_fkey"
            columns: ["fixture_id"]
            isOneToOne: false
            referencedRelation: "fixtures"
            referencedColumns: ["id"]
          },
        ]
      }
      referee_match_report_history: {
        Row: {
          action: string
          changed_by: string | null
          created_at: string
          id: string
          reason: string | null
          report_id: string
          report_version: number
          snapshot: Json
        }
        Insert: {
          action: string
          changed_by?: string | null
          created_at?: string
          id?: string
          reason?: string | null
          report_id: string
          report_version: number
          snapshot: Json
        }
        Update: {
          action?: string
          changed_by?: string | null
          created_at?: string
          id?: string
          reason?: string | null
          report_id?: string
          report_version?: number
          snapshot?: Json
        }
        Relationships: [
          {
            foreignKeyName: "referee_match_report_history_report_id_fkey"
            columns: ["report_id"]
            isOneToOne: false
            referencedRelation: "referee_match_reports"
            referencedColumns: ["id"]
          },
        ]
      }
      referee_match_reports: {
        Row: {
          approved_at: string | null
          approved_by: string | null
          away_score: number
          away_scorers: string[]
          away_substitute_appearances: string[]
          created_at: string
          disciplinary_events: Json
          fixture_id: string
          home_score: number
          home_scorers: string[]
          home_substitute_appearances: string[]
          id: string
          match_write_up: string | null
          referee_user_id: string | null
          report_source: string
          review_reason: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: string
          submitted_at: string
          submitted_by: string | null
          updated_at: string
          version: number
        }
        Insert: {
          approved_at?: string | null
          approved_by?: string | null
          away_score: number
          away_scorers?: string[]
          away_substitute_appearances?: string[]
          created_at?: string
          disciplinary_events?: Json
          fixture_id: string
          home_score: number
          home_scorers?: string[]
          home_substitute_appearances?: string[]
          id?: string
          match_write_up?: string | null
          referee_user_id?: string | null
          report_source: string
          review_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          submitted_at?: string
          submitted_by?: string | null
          updated_at?: string
          version?: number
        }
        Update: {
          approved_at?: string | null
          approved_by?: string | null
          away_score?: number
          away_scorers?: string[]
          away_substitute_appearances?: string[]
          created_at?: string
          disciplinary_events?: Json
          fixture_id?: string
          home_score?: number
          home_scorers?: string[]
          home_substitute_appearances?: string[]
          id?: string
          match_write_up?: string | null
          referee_user_id?: string | null
          report_source?: string
          review_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          submitted_at?: string
          submitted_by?: string | null
          updated_at?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "referee_match_reports_fixture_id_fkey"
            columns: ["fixture_id"]
            isOneToOne: true
            referencedRelation: "fixtures"
            referencedColumns: ["id"]
          },
        ]
      }
      referee_memberships: {
        Row: {
          application_id: string
          approved_at: string
          approved_by: string
          created_at: string
          status: string
          status_changed_at: string
          status_changed_by: string
          status_reason: string
          updated_at: string
          user_id: string
        }
        Insert: {
          application_id: string
          approved_at?: string
          approved_by: string
          created_at?: string
          status?: string
          status_changed_at?: string
          status_changed_by: string
          status_reason: string
          updated_at?: string
          user_id: string
        }
        Update: {
          application_id?: string
          approved_at?: string
          approved_by?: string
          created_at?: string
          status?: string
          status_changed_at?: string
          status_changed_by?: string
          status_reason?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "referee_memberships_application_id_fkey"
            columns: ["application_id"]
            isOneToOne: true
            referencedRelation: "referee_applications"
            referencedColumns: ["id"]
          },
        ]
      }
      referee_milestone_rewards: {
        Row: {
          amount_pence: number
          approved_games: number
          created_at: string
          failure_reason: string | null
          id: string
          milestone_number: number
          processing_started_at: string | null
          referee_user_id: string | null
          status: string
          stripe_transfer_id: string | null
          transfer_attempts: number
          transferred_at: string | null
        }
        Insert: {
          amount_pence?: number
          approved_games: number
          created_at?: string
          failure_reason?: string | null
          id?: string
          milestone_number: number
          processing_started_at?: string | null
          referee_user_id?: string | null
          status?: string
          stripe_transfer_id?: string | null
          transfer_attempts?: number
          transferred_at?: string | null
        }
        Update: {
          amount_pence?: number
          approved_games?: number
          created_at?: string
          failure_reason?: string | null
          id?: string
          milestone_number?: number
          processing_started_at?: string | null
          referee_user_id?: string | null
          status?: string
          stripe_transfer_id?: string | null
          transfer_attempts?: number
          transferred_at?: string | null
        }
        Relationships: [
        ]
      }
      referee_payout_transfer_history: {
        Row: {
          amount_pence: number
          attempt_number: number
          created_at: string
          currency: string
          failure_reason: string | null
          id: string
          payout_id: string
          payout_type: string
          referee_user_id: string | null
          status: string
          stripe_transfer_id: string | null
        }
        Insert: {
          amount_pence: number
          attempt_number: number
          created_at?: string
          currency?: string
          failure_reason?: string | null
          id?: string
          payout_id: string
          payout_type: string
          referee_user_id?: string | null
          status: string
          stripe_transfer_id?: string | null
        }
        Update: {
          amount_pence?: number
          attempt_number?: number
          created_at?: string
          currency?: string
          failure_reason?: string | null
          id?: string
          payout_id?: string
          payout_type?: string
          referee_user_id?: string | null
          status?: string
          stripe_transfer_id?: string | null
        }
        Relationships: [
        ]
      }
      referee_payout_transfer_jobs: {
        Row: {
          attempts: number
          available_at: string
          created_at: string
          first_attempt_at: string | null
          id: string
          last_error: string | null
          lock_token: string | null
          locked_at: string | null
          payout_id: string
          status: string
          updated_at: string
        }
        Insert: {
          attempts?: number
          available_at?: string
          created_at?: string
          first_attempt_at?: string | null
          id?: string
          last_error?: string | null
          lock_token?: string | null
          locked_at?: string | null
          payout_id: string
          status?: string
          updated_at?: string
        }
        Update: {
          attempts?: number
          available_at?: string
          created_at?: string
          first_attempt_at?: string | null
          id?: string
          last_error?: string | null
          lock_token?: string | null
          locked_at?: string | null
          payout_id?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "referee_payout_transfer_jobs_payout_id_fkey"
            columns: ["payout_id"]
            isOneToOne: true
            referencedRelation: "referee_report_payouts"
            referencedColumns: ["id"]
          },
        ]
      }
      referee_report_payouts: {
        Row: {
          created_at: string
          deductions_pence: number
          failure_reason: string | null
          gross_allocation_pence: number
          id: string
          open_play_top_up_pence: number
          processing_started_at: string | null
          referee_net_pence: number
          referee_user_id: string | null
          report_id: string
          status: string
          stripe_transfer_id: string | null
          transfer_attempts: number
          transferred_at: string | null
        }
        Insert: {
          created_at?: string
          deductions_pence?: number
          failure_reason?: string | null
          gross_allocation_pence?: number
          id?: string
          open_play_top_up_pence?: number
          processing_started_at?: string | null
          referee_net_pence?: number
          referee_user_id?: string | null
          report_id: string
          status?: string
          stripe_transfer_id?: string | null
          transfer_attempts?: number
          transferred_at?: string | null
        }
        Update: {
          created_at?: string
          deductions_pence?: number
          failure_reason?: string | null
          gross_allocation_pence?: number
          id?: string
          open_play_top_up_pence?: number
          processing_started_at?: string | null
          referee_net_pence?: number
          referee_user_id?: string | null
          report_id?: string
          status?: string
          stripe_transfer_id?: string | null
          transfer_attempts?: number
          transferred_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "referee_report_payouts_report_id_fkey"
            columns: ["report_id"]
            isOneToOne: true
            referencedRelation: "referee_match_reports"
            referencedColumns: ["id"]
          },
        ]
      }
      season_fee_configs: {
        Row: {
          changed_by: string | null
          created_at: string
          effective_from_gameweek: number
          id: string
          player_fee_pence: number | null
          reason: string | null
          season_id: string
          team_fee_pence: number
        }
        Insert: {
          changed_by?: string | null
          created_at?: string
          effective_from_gameweek?: number
          id?: string
          player_fee_pence?: number | null
          reason?: string | null
          season_id: string
          team_fee_pence: number
        }
        Update: {
          changed_by?: string | null
          created_at?: string
          effective_from_gameweek?: number
          id?: string
          player_fee_pence?: number | null
          reason?: string | null
          season_id?: string
          team_fee_pence?: number
        }
        Relationships: [
          {
            foreignKeyName: "season_fee_configs_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
        ]
      }
      season_gameweeks: {
        Row: {
          created_at: string
          id: string
          scheduled_at: string | null
          season_id: string
          updated_at: string
          week_number: number
        }
        Insert: {
          created_at?: string
          id?: string
          scheduled_at?: string | null
          season_id: string
          updated_at?: string
          week_number: number
        }
        Update: {
          created_at?: string
          id?: string
          scheduled_at?: string | null
          season_id?: string
          updated_at?: string
          week_number?: number
        }
        Relationships: [
          {
            foreignKeyName: "season_gameweeks_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
        ]
      }
      season_registrations: {
        Row: {
          id: string
          reviewed_at: string | null
          reviewed_by: string | null
          season_id: string
          status: Database["public"]["Enums"]["registration_status"]
          submitted_at: string
          user_id: string
        }
        Insert: {
          id?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          season_id: string
          status?: Database["public"]["Enums"]["registration_status"]
          submitted_at?: string
          user_id: string
        }
        Update: {
          id?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          season_id?: string
          status?: Database["public"]["Enums"]["registration_status"]
          submitted_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "season_registrations_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "season_registrations_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      season_teams: {
        Row: {
          approved_at: string | null
          approved_by: string | null
          badge_path: string | null
          created_at: string
          id: string
          name: string
          primary_colour: string | null
          registration_status: Database["public"]["Enums"]["registration_status"]
          season_id: string
          secondary_colour: string | null
          slug: string
          team_id: string
          updated_at: string
        }
        Insert: {
          approved_at?: string | null
          approved_by?: string | null
          badge_path?: string | null
          created_at?: string
          id?: string
          name: string
          primary_colour?: string | null
          registration_status?: Database["public"]["Enums"]["registration_status"]
          season_id: string
          secondary_colour?: string | null
          slug: string
          team_id: string
          updated_at?: string
        }
        Update: {
          approved_at?: string | null
          approved_by?: string | null
          badge_path?: string | null
          created_at?: string
          id?: string
          name?: string
          primary_colour?: string | null
          registration_status?: Database["public"]["Enums"]["registration_status"]
          season_id?: string
          secondary_colour?: string | null
          slug?: string
          team_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "season_teams_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "season_teams_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["id"]
          },
        ]
      }
      seasons: {
        Row: {
          created_at: string
          default_venue_id: string | null
          matchday_weekday: number | null
          matchday_start_time: string | null
          match_duration_minutes: number | null
          matchday_buffer_minutes: number
          round_robin_mode: string
          ends_on: string | null
          id: string
          is_public: boolean
          league_id: string
          name: string
          registration_closes_at: string | null
          recruitment_opened_at: string | null
          recruitment_opened_by: string | null
          recruitment_closed_at: string | null
          recruitment_closed_by: string | null
          recruitment_status: string
          registration_opens_at: string | null
          season_number: number | null
          starts_on: string | null
          status: Database["public"]["Enums"]["season_status"]
          updated_at: string
          points_for_draw: number
          points_for_loss: number
          points_for_win: number
        }
        Insert: {
          created_at?: string
          default_venue_id?: string | null
          matchday_weekday?: number | null
          matchday_start_time?: string | null
          match_duration_minutes?: number | null
          matchday_buffer_minutes?: number
          round_robin_mode?: string
          ends_on?: string | null
          id?: string
          is_public?: boolean
          league_id: string
          name: string
          registration_closes_at?: string | null
          recruitment_opened_at?: string | null
          recruitment_opened_by?: string | null
          recruitment_closed_at?: string | null
          recruitment_closed_by?: string | null
          recruitment_status?: string
          registration_opens_at?: string | null
          season_number?: number | null
          starts_on?: string | null
          status?: Database["public"]["Enums"]["season_status"]
          updated_at?: string
          points_for_draw?: number
          points_for_loss?: number
          points_for_win?: number
        }
        Update: {
          created_at?: string
          default_venue_id?: string | null
          matchday_weekday?: number | null
          matchday_start_time?: string | null
          match_duration_minutes?: number | null
          matchday_buffer_minutes?: number
          round_robin_mode?: string
          ends_on?: string | null
          id?: string
          is_public?: boolean
          league_id?: string
          name?: string
          registration_closes_at?: string | null
          recruitment_opened_at?: string | null
          recruitment_opened_by?: string | null
          recruitment_closed_at?: string | null
          recruitment_closed_by?: string | null
          recruitment_status?: string
          registration_opens_at?: string | null
          season_number?: number | null
          starts_on?: string | null
          status?: Database["public"]["Enums"]["season_status"]
          updated_at?: string
          points_for_draw?: number
          points_for_loss?: number
          points_for_win?: number
        }
        Relationships: [
          {
            foreignKeyName: "seasons_league_id_fkey"
            columns: ["league_id"]
            isOneToOne: false
            referencedRelation: "leagues"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "seasons_default_venue_id_fkey"
            columns: ["default_venue_id"]
            isOneToOne: false
            referencedRelation: "venues"
            referencedColumns: ["id"]
          },
        ]
      }
      stripe_webhook_events: {
        Row: {
          created_at: string
          event_type: string
          id: string
          livemode: boolean
          payment_record_id: string | null
          processed_at: string | null
          processing_error: string | null
          processing_started_at: string | null
        }
        Insert: {
          created_at?: string
          event_type: string
          id: string
          livemode?: boolean
          payment_record_id?: string | null
          processed_at?: string | null
          processing_error?: string | null
          processing_started_at?: string | null
        }
        Update: {
          created_at?: string
          event_type?: string
          id?: string
          livemode?: boolean
          payment_record_id?: string | null
          processed_at?: string | null
          processing_error?: string | null
          processing_started_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "stripe_webhook_events_payment_record_id_fkey"
            columns: ["payment_record_id"]
            isOneToOne: false
            referencedRelation: "payment_records"
            referencedColumns: ["id"]
          },
        ]
      }
      team_fixture_payment_history: {
        Row: {
          action: string
          actor_user_id: string | null
          created_at: string
          from_status: string | null
          id: string
          metadata: Json
          obligation_id: string
          reason: string
          to_status: string | null
        }
        Insert: {
          action: string
          actor_user_id?: string | null
          created_at?: string
          from_status?: string | null
          id?: string
          metadata?: Json
          obligation_id: string
          reason: string
          to_status?: string | null
        }
        Update: {
          action?: string
          actor_user_id?: string | null
          created_at?: string
          from_status?: string | null
          id?: string
          metadata?: Json
          obligation_id?: string
          reason?: string
          to_status?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "team_fixture_payment_history_obligation_id_fkey"
            columns: ["obligation_id"]
            isOneToOne: false
            referencedRelation: "team_fixture_payment_obligations"
            referencedColumns: ["id"]
          },
        ]
      }
      team_fixture_payment_obligations: {
        Row: {
          amount_pence: number
          checkout_attempt: number
          created_at: string
          created_by: string
          currency: string
          deadline_at: string
          defaulted_at: string | null
          finance_cancellation_credit_entry_id: string | null
          finance_charge_entry_id: string | null
          finance_payment_entry_id: string | null
          fixture_id: string
          grace_ends_at: string
          id: string
          paid_at: string | null
          payment_cycle: number
          scheduled_at_snapshot: string
          season_team_id: string
          status: string
          stripe_checkout_session_id: string | null
          stripe_payment_intent_id: string | null
          updated_at: string
        }
        Insert: {
          amount_pence: number
          checkout_attempt?: number
          created_at?: string
          created_by: string
          currency?: string
          deadline_at: string
          defaulted_at?: string | null
          finance_cancellation_credit_entry_id?: string | null
          finance_charge_entry_id?: string | null
          finance_payment_entry_id?: string | null
          fixture_id: string
          grace_ends_at: string
          id?: string
          paid_at?: string | null
          payment_cycle?: number
          scheduled_at_snapshot: string
          season_team_id: string
          status?: string
          stripe_checkout_session_id?: string | null
          stripe_payment_intent_id?: string | null
          updated_at?: string
        }
        Update: {
          amount_pence?: number
          checkout_attempt?: number
          created_at?: string
          created_by?: string
          currency?: string
          deadline_at?: string
          defaulted_at?: string | null
          finance_cancellation_credit_entry_id?: string | null
          finance_charge_entry_id?: string | null
          finance_payment_entry_id?: string | null
          fixture_id?: string
          grace_ends_at?: string
          id?: string
          paid_at?: string | null
          payment_cycle?: number
          scheduled_at_snapshot?: string
          season_team_id?: string
          status?: string
          stripe_checkout_session_id?: string | null
          stripe_payment_intent_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "team_fixture_payment_obligati_finance_cancellation_credit__fkey"
            columns: ["finance_cancellation_credit_entry_id"]
            isOneToOne: false
            referencedRelation: "finance_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_fixture_payment_obligations_finance_charge_entry_id_fkey"
            columns: ["finance_charge_entry_id"]
            isOneToOne: false
            referencedRelation: "finance_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_fixture_payment_obligations_finance_payment_entry_id_fkey"
            columns: ["finance_payment_entry_id"]
            isOneToOne: false
            referencedRelation: "finance_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_fixture_payment_obligations_fixture_id_fkey"
            columns: ["fixture_id"]
            isOneToOne: false
            referencedRelation: "fixtures"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_fixture_payment_obligations_season_team_id_fkey"
            columns: ["season_team_id"]
            isOneToOne: false
            referencedRelation: "season_teams"
            referencedColumns: ["id"]
          },
        ]
      }
      team_fixture_payment_refunds: {
        Row: {
          amount_pence: number
          created_at: string
          credit_finance_entry_id: string | null
          failure_reason: string | null
          id: string
          obligation_id: string
          refund_finance_entry_id: string | null
          status: string
          stripe_payment_intent_id: string
          stripe_refund_id: string | null
          updated_at: string
        }
        Insert: {
          amount_pence: number
          created_at?: string
          credit_finance_entry_id?: string | null
          failure_reason?: string | null
          id?: string
          obligation_id: string
          refund_finance_entry_id?: string | null
          status?: string
          stripe_payment_intent_id: string
          stripe_refund_id?: string | null
          updated_at?: string
        }
        Update: {
          amount_pence?: number
          created_at?: string
          credit_finance_entry_id?: string | null
          failure_reason?: string | null
          id?: string
          obligation_id?: string
          refund_finance_entry_id?: string | null
          status?: string
          stripe_payment_intent_id?: string
          stripe_refund_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "team_fixture_payment_refunds_credit_finance_entry_id_fkey"
            columns: ["credit_finance_entry_id"]
            isOneToOne: false
            referencedRelation: "finance_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_fixture_payment_refunds_obligation_id_fkey"
            columns: ["obligation_id"]
            isOneToOne: true
            referencedRelation: "team_fixture_payment_obligations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_fixture_payment_refunds_refund_finance_entry_id_fkey"
            columns: ["refund_finance_entry_id"]
            isOneToOne: false
            referencedRelation: "finance_entries"
            referencedColumns: ["id"]
          },
        ]
      }
      team_memberships: {
        Row: {
          created_at: string
          id: string
          is_captain: boolean
          joined_at: string | null
          left_at: string | null
          season_team_id: string
          squad_number: number | null
          status: Database["public"]["Enums"]["membership_status"]
          transfer_request_id: string | null
          voluntarily_left_at: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          is_captain?: boolean
          joined_at?: string | null
          left_at?: string | null
          season_team_id: string
          squad_number?: number | null
          status?: Database["public"]["Enums"]["membership_status"]
          transfer_request_id?: string | null
          voluntarily_left_at?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          is_captain?: boolean
          joined_at?: string | null
          left_at?: string | null
          season_team_id?: string
          squad_number?: number | null
          status?: Database["public"]["Enums"]["membership_status"]
          transfer_request_id?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "team_memberships_season_team_id_fkey"
            columns: ["season_team_id"]
            isOneToOne: false
            referencedRelation: "season_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_memberships_transfer_request_id_fkey"
            columns: ["transfer_request_id"]
            isOneToOne: false
            referencedRelation: "player_transfer_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_memberships_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      team_payment_strikes: {
        Row: {
          created_at: string
          fixture_id: string
          id: string
          obligation_id: string
          original_deadline_at: string
          paid_at: string | null
          reason: string
          season_team_id: string
        }
        Insert: {
          created_at?: string
          fixture_id: string
          id?: string
          obligation_id: string
          original_deadline_at: string
          paid_at?: string | null
          reason: string
          season_team_id: string
        }
        Update: {
          created_at?: string
          fixture_id?: string
          id?: string
          obligation_id?: string
          original_deadline_at?: string
          paid_at?: string | null
          reason?: string
          season_team_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "team_payment_strikes_fixture_id_fkey"
            columns: ["fixture_id"]
            isOneToOne: false
            referencedRelation: "fixtures"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_payment_strikes_obligation_id_fkey"
            columns: ["obligation_id"]
            isOneToOne: true
            referencedRelation: "team_fixture_payment_obligations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_payment_strikes_season_team_id_fkey"
            columns: ["season_team_id"]
            isOneToOne: false
            referencedRelation: "season_teams"
            referencedColumns: ["id"]
          },
        ]
      }
      team_stripe_webhook_events: {
        Row: {
          created_at: string
          event_type: string
          id: string
          obligation_id: string | null
          processed_at: string | null
          processing_error: string | null
          processing_started_at: string | null
        }
        Insert: {
          created_at?: string
          event_type: string
          id: string
          obligation_id?: string | null
          processed_at?: string | null
          processing_error?: string | null
          processing_started_at?: string | null
        }
        Update: {
          created_at?: string
          event_type?: string
          id?: string
          obligation_id?: string | null
          processed_at?: string | null
          processing_error?: string | null
          processing_started_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "team_stripe_webhook_events_obligation_id_fkey"
            columns: ["obligation_id"]
            isOneToOne: false
            referencedRelation: "team_fixture_payment_obligations"
            referencedColumns: ["id"]
          },
        ]
      }
      teams: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
        }
        Relationships: []
      }
      transfer_requests: {
        Row: {
          created_at: string
          from_membership_id: string | null
          id: string
          message: string | null
          player_id: string
          reviewed_at: string | null
          reviewed_by: string | null
          status: Database["public"]["Enums"]["transfer_status"]
          target_season_team_id: string
        }
        Insert: {
          created_at?: string
          from_membership_id?: string | null
          id?: string
          message?: string | null
          player_id: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["transfer_status"]
          target_season_team_id: string
        }
        Update: {
          created_at?: string
          from_membership_id?: string | null
          id?: string
          message?: string | null
          player_id?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["transfer_status"]
          target_season_team_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "transfer_requests_from_membership_id_fkey"
            columns: ["from_membership_id"]
            isOneToOne: false
            referencedRelation: "team_memberships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "transfer_requests_player_id_fkey"
            columns: ["player_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "transfer_requests_target_season_team_id_fkey"
            columns: ["target_season_team_id"]
            isOneToOne: false
            referencedRelation: "season_teams"
            referencedColumns: ["id"]
          },
        ]
      }
      user_roles: {
        Row: {
          granted_at: string
          granted_by: string | null
          id: string
          role: string
          user_id: string
        }
        Insert: {
          granted_at?: string
          granted_by?: string | null
          id?: string
          role: string
          user_id: string
        }
        Update: {
          granted_at?: string
          granted_by?: string | null
          id?: string
          role?: string
          user_id?: string
        }
        Relationships: []
      }
      venues: {
        Row: {
          address: string | null
          closes_at: string | null
          created_at: string
          id: string
          is_active: boolean
          location_id: string
          name: string
          operating_days: number[]
          opens_at: string | null
          updated_at: string
        }
        Insert: {
          address?: string | null
          closes_at?: string | null
          created_at?: string
          id?: string
          is_active?: boolean
          location_id: string
          name: string
          operating_days?: number[]
          opens_at?: string | null
          updated_at?: string
        }
        Update: {
          address?: string | null
          closes_at?: string | null
          created_at?: string
          id?: string
          is_active?: boolean
          location_id?: string
          name?: string
          operating_days?: number[]
          opens_at?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "venues_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      _resolve_player_transfer_request: {
        Args: { p_actor: string; p_admin_override: boolean; p_decision: string; p_reason: string; p_request_id: string }
        Returns: Database["public"]["Tables"]["player_transfer_requests"]["Row"]
      }
      _save_referee_match_report: {
        Args: { p_actor: string; p_away_score: number; p_away_scorers: string[]; p_away_substitute_appearances: string[]; p_disciplinary_events: Json; p_fixture_id: string; p_home_score: number; p_home_scorers: string[]; p_home_substitute_appearances: string[]; p_match_write_up: string; p_reason: string; p_source: string }
        Returns: string
      }
      admin_add_player_to_team: {
        Args: {
          p_make_captain?: boolean
          p_season_team_id: string
          p_user_id: string
        }
        Returns: {
          created_at: string
          id: string
          is_captain: boolean
          joined_at: string | null
          left_at: string | null
          season_team_id: string
          squad_number: number | null
          status: Database["public"]["Enums"]["membership_status"]
          transfer_request_id: string | null
          voluntarily_left_at: string | null
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "team_memberships"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_amend_team_sheet: {
        Args: {
          p_goalkeeper_membership_id?: string
          p_reason?: string
          p_starters: string[]
          p_substitutes?: string[]
          p_team_sheet_id: string
        }
        Returns: {
          draft_saved_at: string | null
          fixture_id: string
          id: string
          is_locked: boolean
          season_team_id: string
          submitted_at: string | null
          submitted_by: string
        }
        SetofOptions: {
          from: "*"
          to: "fixture_team_sheets"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_assign_referee_to_fixture: {
        Args: { p_assignment_role: string; p_fixture_id: string; p_referee_user_id: string }
        Returns: Database["public"]["Tables"]["referee_fixture_assignments"]["Row"]
      }
      admin_cancel_referee_fixture_assignment: {
        Args: { p_assignment_id: string; p_reason: string }
        Returns: Database["public"]["Tables"]["referee_fixture_assignments"]["Row"]
      }
      admin_claim_player_account_inactivity_warnings: {
        Args: Record<PropertyKey, never>
        Returns: { closure_at: string; email: string; inactivity_started_at: string; user_id: string; warning_days: number }[]
      }
      admin_close_inactive_player_account: {
        Args: { p_user_id: string }
        Returns: boolean
      }
      admin_close_season_recruitment: {
        Args: { p_reason: string; p_season_id: string }
        Returns: Database["public"]["Tables"]["seasons"]["Row"]
      }
      admin_correct_approved_referee_match_report: {
        Args: { p_away_score: number; p_away_scorers: string[]; p_away_substitute_appearances: string[]; p_disciplinary_events: Json; p_expected_version: number; p_home_score: number; p_home_scorers: string[]; p_home_substitute_appearances: string[]; p_match_write_up: string; p_reason: string; p_report_id: string }
        Returns: number
      }
      admin_correct_fixture_motm_nomination: {
        Args: { p_nomination_id: string; p_competition_player_id: string; p_reason: string }
        Returns: undefined
      }
      admin_create_finance_entry: {
        Args: {
          p_amount_pence: number
          p_description: string
          p_due_at?: string
          p_entry_type: string
          p_fixture_id?: string
          p_notes?: string
          p_payment_method?: string
          p_reference?: string
          p_season_team_id: string
        }
        Returns: {
          amount_pence: number
          created_at: string
          created_by: string
          description: string
          due_at: string | null
          entry_type: string
          fixture_id: string | null
          id: string
          notes: string | null
          occurred_at: string
          payment_method: string | null
          reference: string | null
          season_team_id: string
        }
        SetofOptions: {
          from: "*"
          to: "finance_entries"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_create_fixture: {
        Args: {
          p_away_team_id: string
          p_fixture_number: number
          p_gameweek: number
          p_home_team_id: string
          p_notes?: string
          p_scheduled_at?: string
          p_season_id: string
          p_venue_id?: string
        }
        Returns: {
          away_team_id: string
          created_at: string
          fixture_number: number
          gameweek: number
          home_team_id: string
          id: string
          notes: string | null
          scheduled_at: string | null
          season_id: string
          status: Database["public"]["Enums"]["fixture_status"]
          updated_at: string
          venue_id: string | null
        }
        SetofOptions: {
          from: "*"
          to: "fixtures"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_create_league: {
        Args: {
          p_description?: string
          p_format: Database["public"]["Enums"]["competition_format"]
          p_location_id: string
          p_name: string
        }
        Returns: {
          created_at: string
          description: string | null
          format: Database["public"]["Enums"]["competition_format"]
          id: string
          is_published: boolean
          location_id: string
          name: string
          slug: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "leagues"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_create_location: {
        Args: {
          p_address?: string
          p_name: string
          p_region?: string
          p_town: string
        }
        Returns: {
          address: string | null
          created_at: string
          id: string
          is_active: boolean
          name: string
          region: string
          slug: string
          town: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "locations"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_create_message_broadcast: {
        Args: { p_body: string; p_target_id?: string; p_target_type: string; p_title: string }
        Returns: string
      }
      admin_create_operating_cost: {
        Args: { p_amount_pence: number; p_category: string; p_description: string; p_league_id?: string; p_location_id?: string; p_notes?: string; p_occurred_at: string; p_reason?: string; p_reference?: string; p_season_id?: string }
        Returns: Database["public"]["Tables"]["finance_operating_costs"]["Row"]
      }
      admin_create_season: {
        Args: {
          p_ends_on?: string
          p_league_id: string
          p_name: string
          p_registration_closes_at?: string
          p_registration_opens_at?: string
          p_season_number?: number
          p_starts_on?: string
        }
        Returns: {
          created_at: string
          ends_on: string | null
          id: string
          is_public: boolean
          league_id: string
          name: string
          registration_closes_at: string | null
          registration_opens_at: string | null
          season_number: number | null
          starts_on: string | null
          status: Database["public"]["Enums"]["season_status"]
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "seasons"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_create_season_team: {
        Args: {
          p_primary_colour?: string
          p_season_id: string
          p_secondary_colour?: string
          p_team_name: string
        }
        Returns: {
          approved_at: string | null
          approved_by: string | null
          badge_path: string | null
          created_at: string
          id: string
          name: string
          primary_colour: string | null
          registration_status: Database["public"]["Enums"]["registration_status"]
          season_id: string
          secondary_colour: string | null
          slug: string
          team_id: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "season_teams"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_create_title_final: {
        Args: {
          p_away_team_id: string
          p_home_team_id: string
          p_reason?: string
          p_scheduled_at: string
          p_season_id: string
          p_venue_id?: string
        }
        Returns: Database["public"]["Tables"]["fixtures"]["Row"]
      }
      admin_create_venue: {
        Args: {
          p_location_id: string
          p_name: string
          p_address?: string | null
          p_operating_days?: number[]
          p_opens_at?: string | null
          p_closes_at?: string | null
          p_is_active?: boolean
        }
        Returns: Database["public"]["Tables"]["venues"]["Row"]
        SetofOptions: {
          from: "*"
          to: "venues"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_finish_player_account_inactivity_warning: {
        Args: { p_delivered: boolean; p_inactivity_started_at: string; p_user_id: string; p_warning_days: number }
        Returns: boolean
      }
      admin_generate_round_robin_fixtures: {
        Args: { p_season_id: string; p_first_matchday_date: string; p_expected_settings_hash: string }
        Returns: Json
      },
      admin_get_approved_referee_report_correction_options: {
        Args: { p_report_id: string }
        Returns: Json
      }
      admin_get_guardian_consent_queue: {
        Args: never
        Returns: {
          created_at: string
          guardian_email: string
          guardian_full_name: string
          id: string
          player_date_of_birth: string
          player_email: string
          player_user_id: string
          status: string
          verified_at: string | null
        }[]
      }
      admin_get_message_reports: {
        Args: { p_limit?: number; p_status?: string }
        Returns: { conversation_id: string; conversation_title: string; created_at: string; location_id: string; message_body: string; message_id: string; reason: string; report_id: string; reported_user_name: string; reporter_name: string; status: string }[]
      }
      admin_get_message_target_options: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      admin_get_notification_dispatch_status: {
        Args: never
        Returns: {
          enabled: boolean
          reason: string
          schedule_active: boolean
          updated_at: string
          updated_by: string
          vault_credentials_configured: boolean
        }[]
      }
      admin_get_notification_events: {
        Args: { p_limit?: number; p_offset?: number; p_status?: string }
        Returns: {
          attempt_count: number
          channel: string
          created_at: string
          event_type: string
          held_at: string
          hold_reason: string
          id: string
          last_attempt_at: string
          last_error: string
          manual_retry_used: boolean
          next_attempt_at: string
          payload: Json
          read_at: string
          recipient_email: string
          recipient_name: string
          recipient_phone: string
          sent_at: string
          status: string
          user_id: string
        }[]
      }
      admin_get_player_detail: { Args: { p_user_id: string }; Returns: Json }
      admin_get_referee_fixture_report_options: {
        Args: { p_fixture_id: string }
        Returns: Json
      }
      admin_get_referee_payout_transfer_history: {
        Args: { p_payout_type: string; p_payout_id: string }
        Returns: {
          attempt_number: number; status: string; amount_pence: number;
          stripe_transfer_id: string | null; failure_reason: string | null; created_at: string;
        }[]
      }
      admin_get_transfer_requests: {
        Args: { p_status?: string }
        Returns: {
          destination_team_id: string
          destination_team_name: string
          id: string
          league_name: string
          player_name: string | null
          reason: string
          requested_at: string
          season_name: string
          source_membership_id: string | null
          source_team_name: string
          status: string
          user_id: string | null
        }[]
      }
      admin_get_transfer_requests_contextual: {
        Args: {
          p_league_id?: string
          p_location_id?: string
          p_season_id?: string
          p_status?: string
        }
        Returns: {
          destination_team_id: string
          destination_team_name: string
          id: string
          league_name: string
          player_name: string
          reason: string
          requested_at: string
          season_name: string
          source_membership_id: string | null
          source_team_name: string
          status: string
          user_id: string | null
        }[]
      }
      admin_list_disciplinary_suspensions: {
        Args: { p_location_id?: string | null }
        Returns: {
          competition_player_id: string
          player_name: string
          disciplinary_strikes: number
          last_straight_red_at: string
          last_fixture_id: string
          last_gameweek: number
          last_team_name: string
        }[]
      }
      admin_list_expired_player_account_archives: {
        Args: never
        Returns: { archive_expires_at: string; email: string | null; user_id: string }[]
      }
      admin_list_fixture_motm_nominations: {
        Args: { p_location_id?: string | null }
        Returns: {
          nomination_id: string
          fixture_id: string
          season_team_id: string
          team_name: string
          opponent_name: string
          gameweek: number
          scheduled_at: string | null
          location_id: string
          location_name: string
          competition_player_id: string
          nominated_player_name: string
          nominated_by: string
          nominated_at: string
          corrected_at: string | null
          correction_reason: string | null
          eligible_players: Json
        }[]
      }
      admin_list_inactive_player_accounts: {
        Args: never
        Returns: { email: string | null; last_sign_in_at: string; user_id: string }[]
      }
      admin_list_location_assignments: {
        Args: { p_location_id?: string }
        Returns: {
          assigned_at: string
          assignment_id: string
          location_id: string
          location_name: string
          user_id: string
        }[]
      }
      admin_list_player_retention_accounts: {
        Args: { p_search?: string | null }
        Returns: {
          account_closed_at: string | null
          account_retention_status: string
          archive_expires_at: string | null
          email: string | null
          full_name: string
          last_sign_in_at: string
          retention_hold: boolean
          retention_hold_reason: string | null
          user_id: string
        }[]
      }
      admin_list_referee_applications: {
        Args: { p_status?: string }
        Returns: { additional_notes: string; application_id: string; availability: Json; contact_phone: string; email: string; experience_summary: string; player_name: string; preferred_location_ids: string[]; preferred_location_names: string[]; qualifications: string[]; review_reason: string; reviewed_at: string; status: string; submitted_at: string; user_id: string }[]
      }
      admin_list_referee_appointments: {
        Args: { p_include_cancelled?: boolean; p_location_id?: string }
        Returns: { assigned_at: string; assignment_id: string; assignment_role: string; away_team_name: string; cancellation_reason: string; cancelled_at: string; fixture_id: string; fixture_number: number; gameweek: number; home_team_name: string; location_id: string; location_name: string; referee_email: string; referee_name: string; referee_user_id: string; scheduled_at: string }[]
      }
      admin_list_referee_assignment_candidates: {
        Args: { p_location_id?: string }
        Returns: { availability: Json; preferred_location_ids: string[]; referee_email: string; referee_name: string; referee_user_id: string }[]
      }
      admin_list_referee_assignment_fixtures: {
        Args: Record<PropertyKey, never>
        Returns: { away_team_name: string; fixture_id: string; fixture_number: number; gameweek: number; home_team_name: string; location_id: string; location_name: string; scheduled_at: string }[]
      }
      admin_list_referee_match_reports: {
        Args: { p_location_id?: string; p_status?: string }
        Returns: { away_score: number; away_scorers: string[]; away_substitute_appearances: string[]; away_team_name: string; disciplinary_events: Json; fixture_id: string; fixture_number: number; gameweek: number; home_score: number; home_scorers: string[]; home_substitute_appearances: string[]; home_team_name: string; location_id: string; location_name: string; match_write_up: string; referee_email: string; referee_name: string; referee_user_id: string; report_id: string; report_source: string; review_reason: string; scheduled_at: string; status: string; submitted_at: string; version: number }[]
      }
      admin_list_referee_milestone_rewards_connect: {
        Args: { p_status?: string | null }
        Returns: {
          reward_id: string; referee_user_id: string | null; referee_name: string;
          milestone_number: number; approved_games: number; amount_pence: number;
          status: string; stripe_transfer_id: string | null; failure_reason: string | null;
          transfer_attempts: number; connect_status: string; transfers_enabled: boolean;
          payouts_enabled: boolean; created_at: string; transferred_at: string | null;
        }[]
      }
      admin_list_referee_report_payouts: {
        Args: { p_location_id?: string; p_status?: string }
        Returns: { created_at: string; deductions_pence: number; fixture_id: string; fixture_number: number; gameweek: number; gross_allocation_pence: number; location_id: string; location_name: string; open_play_top_up_pence: number; payout_id: string; referee_email: string; referee_name: string; referee_net_pence: number; referee_user_id: string; report_id: string; scheduled_at: string; status: string; stripe_transfer_id: string; transferred_at: string }[]
      }
      admin_list_referee_report_payouts_connect: {
        Args: { p_status?: string | null }
        Returns: {
          payout_id: string; report_id: string; referee_user_id: string | null;
          referee_name: string; referee_email: string | null; fixture_id: string;
          gameweek: number; fixture_number: number; scheduled_at: string | null;
          location_id: string; location_name: string; gross_allocation_pence: number;
          deductions_pence: number; referee_net_pence: number; open_play_top_up_pence: number;
          status: string; stripe_transfer_id: string | null; failure_reason: string | null;
          transfer_attempts: number; connect_status: string; transfers_enabled: boolean;
          payouts_enabled: boolean; created_at: string; transferred_at: string | null;
        }[]
      }
      admin_list_referee_reportable_fixtures: {
        Args: { p_location_id?: string }
        Returns: { away_team_id: string; away_team_name: string; existing_report_id: string; existing_report_status: string; fixture_id: string; fixture_number: number; gameweek: number; home_team_id: string; home_team_name: string; location_id: string; location_name: string; scheduled_at: string }[]
      }
      admin_mark_player_account_erasure_due: {
        Args: { p_user_id: string }
        Returns: boolean
      }
      admin_open_season_recruitment: {
        Args: { p_reason: string; p_season_id: string }
        Returns: Database["public"]["Tables"]["seasons"]["Row"]
      }
      admin_postpone_gameweek: {
        Args: { p_gameweek_id: string; p_replacement_at: string; p_reason: string }
        Returns: Json
      }
      admin_prepare_player_account_erasure: {
        Args: { p_user_id: string }
        Returns: boolean
      }
      admin_preview_round_robin_fixtures: {
        Args: { p_season_id: string; p_first_matchday_date: string }
        Returns: Json
      },
      admin_publish_upcoming_season: {
        Args: { p_reason: string; p_season_id: string }
        Returns: Database["public"]["Tables"]["seasons"]["Row"]
      }
      admin_reactivate_disciplined_player: {
        Args: { p_competition_player_id: string; p_reason: string }
        Returns: undefined
      }
      admin_record_fixture_goal_events: {
        Args: { p_events: Json; p_fixture_id: string; p_reason: string }
        Returns: Json
      }
      admin_record_fixture_result: {
        Args: {
          p_away_score: number
          p_away_scorers?: string[]
          p_fixture_id: string
          p_home_score: number
          p_home_scorers?: string[]
          p_reason?: string
        }
        Returns: {
          away_score: number
          confirmed_at: string | null
          confirmed_by: string | null
          fixture_id: string
          home_score: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "fixture_results"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_record_fixture_result_with_appearances: {
        Args: {
          p_away_score: number
          p_away_scorers?: string[]
          p_away_substitute_appearances?: string[]
          p_fixture_id: string
          p_home_score: number
          p_home_scorers?: string[]
          p_home_substitute_appearances?: string[]
          p_reason?: string
        }
        Returns: {
          away_score: number
          confirmed_at: string | null
          confirmed_by: string | null
          fixture_id: string
          home_score: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "fixture_results"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_register_gallery_item: {
        Args: {
          p_caption?: string
          p_location_id: string
          p_object_path: string
        }
        Returns: string
      }
      admin_remove_player_from_team: {
        Args: { p_membership_id: string; p_reason: string }
        Returns: {
          created_at: string
          id: string
          is_captain: boolean
          joined_at: string | null
          left_at: string | null
          season_team_id: string
          squad_number: number | null
          status: Database["public"]["Enums"]["membership_status"]
          transfer_request_id: string | null
          voluntarily_left_at: string | null
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "team_memberships"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_resolve_message_report: {
        Args: { p_action: string; p_reason: string; p_report_id: string }
        Returns: undefined
      }
      admin_resolve_player_transfer_request: {
        Args: { p_decision: string; p_reason: string; p_request_id: string }
        Returns: {
          created_at: string
          destination_season_team_id: string
          id: string
          is_emergency: boolean
          league_id: string
          reason: string
          requested_at: string
          resolution_reason: string | null
          resolved_at: string | null
          resolved_by: string | null
          source_membership_id: string | null
          source_season_team_id: string
          status: string
          target_fixture_id: string | null
          updated_at: string
          user_id: string | null
        }
        SetofOptions: {
          from: "*"
          to: "player_transfer_requests"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_retry_notification: {
        Args: { p_event_id: string; p_reason: string }
        Returns: {
          attempt_count: number
          channel: string
          created_at: string
          dedupe_key: string | null
          event_type: string
          held_at: string | null
          held_by: string | null
          hold_reason: string | null
          id: string
          last_attempt_at: string | null
          last_error: string | null
          locked_at: string | null
          manual_retry_used: boolean
          next_attempt_at: string
          payload: Json
          provider_reference: string | null
          read_at: string | null
          sent_at: string | null
          status: string
          unconfirmed_at: string | null
          updated_at: string
          user_id: string | null
        }
        SetofOptions: {
          from: "*"
          to: "notification_events"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_review_guardian_consent: {
        Args: { p_consent_id: string; p_decision: string; p_reason: string }
        Returns: string
      }
      admin_review_referee_match_report: {
        Args: { p_decision: string; p_reason: string; p_report_id: string }
        Returns: undefined
      }
      admin_search_league_admin_role_candidates: {
        Args: { p_query: string }
        Returns: {
          user_id: string
          email: string | null
          display_name: string
          has_league_admin: boolean
        }[]
      }
      admin_search_location_admin_candidates: {
        Args: { p_query: string }
        Returns: {
          display_name: string
          email: string
          user_id: string
        }[]
      }
      admin_set_fixture_status: {
        Args: {
          p_fixture_id: string
          p_next_status: Database["public"]["Enums"]["fixture_status"]
          p_reason?: string
        }
        Returns: {
          away_team_id: string
          created_at: string
          fixture_number: number
          gameweek: number
          home_team_id: string
          id: string
          notes: string | null
          scheduled_at: string | null
          season_id: string
          status: Database["public"]["Enums"]["fixture_status"]
          updated_at: string
          venue_id: string | null
        }
        SetofOptions: {
          from: "*"
          to: "fixtures"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_set_gallery_item_published: {
        Args: { p_is_published: boolean; p_item_id: string }
        Returns: undefined
      }
      admin_set_league_admin_role: {
        Args: { p_user_id: string; p_granted: boolean; p_reason: string }
        Returns: boolean
      }
      admin_set_league_published: {
        Args: { p_is_published: boolean; p_league_id: string }
        Returns: {
          created_at: string
          description: string | null
          format: Database["public"]["Enums"]["competition_format"]
          id: string
          is_published: boolean
          location_id: string
          name: string
          slug: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "leagues"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_set_location_active: {
        Args: { p_is_active: boolean; p_location_id: string; p_reason: string }
        Returns: {
          address: string | null
          created_at: string
          id: string
          is_active: boolean
          name: string
          region: string
          slug: string
          town: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "locations"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_set_location_assignment: {
        Args: { p_assigned: boolean; p_location_id: string; p_user_id: string }
        Returns: undefined
      }
      admin_set_notification_dispatch_enabled: {
        Args: {
          p_confirm_provider_configuration?: boolean
          p_enabled: boolean
          p_reason: string
        }
        Returns: {
          enabled: boolean
          reason: string
          schedule_active: boolean
          updated_at: string
          updated_by: string
          vault_credentials_configured: boolean
        }[]
      }
      admin_set_notification_hold: {
        Args: { p_event_id: string; p_hold: boolean; p_reason?: string }
        Returns: {
          attempt_count: number
          channel: string
          created_at: string
          dedupe_key: string | null
          event_type: string
          held_at: string | null
          held_by: string | null
          hold_reason: string | null
          id: string
          last_attempt_at: string | null
          last_error: string | null
          locked_at: string | null
          manual_retry_used: boolean
          next_attempt_at: string
          payload: Json
          provider_reference: string | null
          read_at: string | null
          sent_at: string | null
          status: string
          unconfirmed_at: string | null
          updated_at: string
          user_id: string | null
        }
        SetofOptions: {
          from: "*"
          to: "notification_events"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_set_platform_feature_flag: {
        Args: { p_enabled: boolean; p_feature_key: string; p_reason: string }
        Returns: Database["public"]["Tables"]["platform_feature_flags"]["Row"]
      }
      admin_set_player_ban: {
        Args: { p_is_banned: boolean; p_reason: string; p_user_id: string }
        Returns: {
          banned_at: string | null
          banned_reason: string | null
          created_at: string
          date_of_birth: string
          email: string
          full_name: string
          id: string
          is_banned: boolean
          is_genuine: boolean
          phone: string
          registration_status: Database["public"]["Enums"]["player_registration_status"]
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "players"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_set_player_fixture_fee: {
        Args: {
          p_effective_from_gameweek: number
          p_player_fee_pence: number
          p_reason: string
          p_season_id: string
        }
        Returns: string
      }
      admin_set_player_genuine: {
        Args: { p_is_genuine: boolean; p_reason: string; p_user_id: string }
        Returns: {
          banned_at: string | null
          banned_reason: string | null
          created_at: string
          date_of_birth: string
          email: string
          full_name: string
          id: string
          is_banned: boolean
          is_genuine: boolean
          phone: string
          registration_status: Database["public"]["Enums"]["player_registration_status"]
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "players"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_set_player_retention_hold: {
        Args: { p_hold: boolean; p_reason: string; p_user_id: string }
        Returns: boolean
      }
      admin_set_season_points: {
        Args: { p_points_for_draw: number; p_points_for_loss: number; p_points_for_win: number; p_reason: string; p_season_id: string }
        Returns: Database["public"]["Tables"]["seasons"]["Row"]
      }
      admin_submit_referee_match_report: {
        Args: { p_away_score: number; p_away_scorers?: string[]; p_away_substitute_appearances?: string[]; p_disciplinary_events?: Json; p_fixture_id: string; p_home_score: number; p_home_scorers?: string[]; p_home_substitute_appearances?: string[]; p_match_write_up?: string; p_reason?: string }
        Returns: string
      }
      admin_transition_season: {
        Args: {
          p_next_status: Database["public"]["Enums"]["season_status"]
          p_season_id: string
        }
        Returns: {
          created_at: string
          ends_on: string | null
          id: string
          is_public: boolean
          league_id: string
          name: string
          registration_closes_at: string | null
          registration_opens_at: string | null
          season_number: number | null
          starts_on: string | null
          status: Database["public"]["Enums"]["season_status"]
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "seasons"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_update_player_profile: {
        Args: {
          p_display_name: string
          p_emergency_contact_name: string
          p_emergency_contact_phone: string
          p_first_name: string
          p_last_name: string
          p_phone: string
          p_preferred_position: string
          p_reason: string
          p_user_id: string
        }
        Returns: Json
      }
      admin_update_season_matchday_settings: {
        Args: {
          p_season_id: string
          p_matchday_weekday: number | null
          p_matchday_start_time: string | null
          p_match_duration_minutes: number | null
          p_matchday_buffer_minutes?: number
          p_default_venue_id?: string | null
          p_round_robin_mode?: string
        }
        Returns: Database["public"]["Tables"]["seasons"]["Row"]
        SetofOptions: {
          from: "*"
          to: "seasons"
          isOneToOne: true
          isSetofReturn: false
        }
      },
      admin_update_venue: {
        Args: {
          p_venue_id: string
          p_name: string
          p_address?: string | null
          p_operating_days?: number[]
          p_opens_at?: string | null
          p_closes_at?: string | null
          p_is_active?: boolean
        }
        Returns: Database["public"]["Tables"]["venues"]["Row"]
        SetofOptions: {
          from: "*"
          to: "venues"
          isOneToOne: true
          isSetofReturn: false
        }
      },
      admin_void_referee_match_report: {
        Args: { p_reason: string; p_report_id: string }
        Returns: undefined
      }
      anonymise_player_audit_json: {
        Args: { p_user_id: string; p_value: Json }
        Returns: Json
      }
      assert_admin_location_context: {
        Args: { p_location_id: string }
        Returns: undefined
      }
      block_message_user: {
        Args: { p_blocked_user_id: string }
        Returns: undefined
      }
      build_round_robin_fixture_schedule: {
        Args: { p_first_matchday_date: string; p_season_id: string }
        Returns: { away_team_id: string; fixture_number: number; gameweek: number; home_team_id: string; scheduled_at: string }[]
      }
      can_access_message_conversation: {
        Args: { p_conversation_id: string }
        Returns: boolean
      }
      can_administer_location: {
        Args: { p_location_id: string }
        Returns: boolean
      }
      cancel_player_transfer_request: {
        Args: { p_request_id: string }
        Returns: {
          created_at: string
          destination_season_team_id: string
          id: string
          is_emergency: boolean
          league_id: string
          reason: string
          requested_at: string
          resolution_reason: string | null
          resolved_at: string | null
          resolved_by: string | null
          source_membership_id: string | null
          source_season_team_id: string
          status: string
          target_fixture_id: string | null
          updated_at: string
          user_id: string | null
        }
        SetofOptions: {
          from: "*"
          to: "player_transfer_requests"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      captain_next_required_fixture: {
        Args: { p_season_team_id: string }
        Returns: string
      }
      claim_notification_events: {
        Args: { p_channels?: string[]; p_limit?: number }
        Returns: {
          attempt_count: number
          channel: string
          created_at: string
          dedupe_key: string | null
          event_type: string
          held_at: string | null
          held_by: string | null
          hold_reason: string | null
          id: string
          last_attempt_at: string | null
          last_error: string | null
          locked_at: string | null
          manual_retry_used: boolean
          next_attempt_at: string
          payload: Json
          provider_reference: string | null
          read_at: string | null
          sent_at: string | null
          status: string
          unconfirmed_at: string | null
          updated_at: string
          user_id: string | null
        }[]
        SetofOptions: {
          from: "*"
          to: "notification_events"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      claim_referee_payout_transfer: {
        Args: { p_payout_type: string; p_payout_id: string }
        Returns: Json
      }
      claim_referee_payout_transfer_jobs: {
        Args: { p_limit?: number }
        Returns: { job_id: string; lock_token: string; payout_id: string }[]
      }
      claim_referee_payout_transfer_worker: {
        Args: { p_job_id: string; p_lock_token: string; p_payout_id: string }
        Returns: Json
      }
      claim_team_fixture_payment_checkout_attempt: {
        Args: { p_expected_session_id?: string; p_obligation_id: string }
        Returns: number
      }
      clear_team_fixture_payment_checkout_session: {
        Args: { p_obligation_id: string; p_session_id: string }
        Returns: boolean
      }
      complete_notification_event: {
        Args: { p_event_id: string; p_provider_reference?: string }
        Returns: {
          attempt_count: number
          channel: string
          created_at: string
          dedupe_key: string | null
          event_type: string
          held_at: string | null
          held_by: string | null
          hold_reason: string | null
          id: string
          last_attempt_at: string | null
          last_error: string | null
          locked_at: string | null
          manual_retry_used: boolean
          next_attempt_at: string
          payload: Json
          provider_reference: string | null
          read_at: string | null
          sent_at: string | null
          status: string
          unconfirmed_at: string | null
          updated_at: string
          user_id: string | null
        }
        SetofOptions: {
          from: "*"
          to: "notification_events"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      complete_player_account_reactivation: {
        Args: { p_token_hash: string; p_user_id: string }
        Returns: boolean
      }
      create_direct_message_conversation: {
        Args: { p_recipient_user_id: string }
        Returns: string
      }
      create_player_fixture_payment: {
        Args: { p_fixture_id: string; p_season_team_id: string }
        Returns: {
          already_paid: boolean
          amount_pence: number
          currency: string
          payment_record_id: string
        }[]
      }
      create_support_message_conversation: {
        Args: { p_initial_message: string; p_subject: string }
        Returns: string
      }
      create_team_fixture_payment_obligation: {
        Args: { p_fixture_id: string; p_season_team_id: string }
        Returns: { amount_pence: number; deadline_at: string; grace_ends_at: string; obligation_id: string; status: string }[]
      }
      dispatch_notification_worker: { Args: never; Returns: number }
      dispatch_referee_payout_transfer_worker: {
        Args: Record<PropertyKey, never>
        Returns: number
      }
      enqueue_fixture_reminders: { Args: never; Returns: number }
      enqueue_notification_event: {
        Args: { p_event_type: string; p_payload: Json; p_user_id: string }
        Returns: undefined
      }
      fail_notification_event: {
        Args: { p_error: string; p_event_id: string }
        Returns: {
          attempt_count: number
          channel: string
          created_at: string
          dedupe_key: string | null
          event_type: string
          held_at: string | null
          held_by: string | null
          hold_reason: string | null
          id: string
          last_attempt_at: string | null
          last_error: string | null
          locked_at: string | null
          manual_retry_used: boolean
          next_attempt_at: string
          payload: Json
          provider_reference: string | null
          read_at: string | null
          sent_at: string | null
          status: string
          unconfirmed_at: string | null
          updated_at: string
          user_id: string | null
        }
        SetofOptions: {
          from: "*"
          to: "notification_events"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      fail_notification_event_permanent: {
        Args: { p_error: string; p_event_id: string }
        Returns: {
          attempt_count: number
          channel: string
          created_at: string
          dedupe_key: string | null
          event_type: string
          held_at: string | null
          held_by: string | null
          hold_reason: string | null
          id: string
          last_attempt_at: string | null
          last_error: string | null
          locked_at: string | null
          manual_retry_used: boolean
          next_attempt_at: string
          payload: Json
          provider_reference: string | null
          read_at: string | null
          sent_at: string | null
          status: string
          unconfirmed_at: string | null
          updated_at: string
          user_id: string | null
        }
        SetofOptions: {
          from: "*"
          to: "notification_events"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      get_active_referee_locations: {
        Args: Record<PropertyKey, never>
        Returns: { id: string; name: string; region: string; town: string }[]
      }
      get_admin_audit_history: {
        Args: { p_limit?: number; p_offset?: number; p_search?: string }
        Returns: {
          action: string
          actor_user_id: string
          created_at: string
          entity_id: string
          entity_type: string
          id: number
          reason: string
        }[]
      }
      get_admin_business_performance: {
        Args: { p_from_date?: string; p_league_id?: string; p_location_id?: string; p_season_id?: string; p_to_date?: string }
        Returns: { net_operating_surplus_pence: number; outstanding_pence: number; player_card_fees_pence: number; player_card_gross_pence: number; player_card_net_pence: number; player_card_refunds_pence: number; recorded_costs_pence: number; team_charges_pence: number; team_credits_pence: number; team_fines_pence: number; team_receipts_pence: number; team_refunds_pence: number; upcoming_team_forecast_pence: number; upcoming_team_obligations: number }[]
      }
      get_admin_competition_setup: { Args: never; Returns: Json }
      get_admin_context_preference: { Args: never; Returns: Json }
      get_admin_contextual_fixtures: {
        Args: {
          p_league_id?: string
          p_location_id?: string
          p_season_id?: string
        }
        Returns: {
          away_score: number | null
          away_team_id: string
          away_team_name: string
          fixture_number: number
          gameweek: number
          home_score: number | null
          home_team_id: string
          home_team_name: string
          id: string
          notes: string | null
          scheduled_at: string | null
          season_id: string
          season_name: string
          status: string
          venue_id: string | null
          venue_name: string | null
        }[]
      }
      get_admin_dashboard: { Args: never; Returns: Json }
      get_admin_dashboard_contextual: {
        Args: {
          p_league_id?: string
          p_location_id?: string
          p_season_id?: string
        }
        Returns: Json
      }
      get_admin_fixture_scorer_options: {
        Args: { p_fixture_id: string }
        Returns: Json
      }
      get_admin_gallery_items: {
        Args: { p_location_id?: string }
        Returns: {
          caption: string
          created_at: string
          id: string
          is_published: boolean
          location_id: string
          location_name: string
          object_path: string
          published_at: string
        }[]
      }
      get_admin_operating_costs: {
        Args: { p_from_date?: string; p_league_id?: string; p_limit?: number; p_location_id?: string; p_season_id?: string; p_to_date?: string }
        Returns: { amount_pence: number; category: string; created_at: string; created_by: string; description: string; id: string; league_id: string; league_name: string; location_id: string; location_name: string; notes: string; occurred_at: string; reference: string; season_id: string; season_name: string }[]
      }
      get_admin_platform_feature_flags: {
        Args: never
        Returns: {
          enabled: boolean
          feature_key: string
          updated_at: string
          updated_by: string | null
        }[]
      }
      get_admin_player_register: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_search?: string
          p_status?: string
        }
        Returns: {
          created_at: string
          email: string
          full_name: string
          is_banned: boolean
          is_genuine: boolean
          phone: string
          preferred_position: string
          registration_status: string
          team_names: string[]
          user_id: string
        }[]
      }
      get_admin_player_register_contextual: {
        Args: {
          p_league_id?: string
          p_limit?: number
          p_location_id?: string
          p_offset?: number
          p_search?: string
          p_season_id?: string
          p_status?: string
        }
        Returns: {
          created_at: string
          email: string
          full_name: string
          is_banned: boolean
          is_genuine: boolean
          phone: string
          preferred_position: string
          registration_status: string
          team_names: string[]
          user_id: string
        }[]
      }
      get_admin_postponable_gameweeks: {
        Args: { p_season_id?: string | null }
        Returns: {
          gameweek_id: string
          season_id: string
          season_name: string
          week_number: number
          scheduled_at: string | null
          fixture_count: number
          paid_team_count: number
          location_name: string | null
        }[]
      }
      get_admin_product_analytics_scope: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      get_admin_registration_conversion: {
        Args: {
          p_from_date?: string | null
          p_to_date?: string | null
          p_location_id?: string | null
          p_league_id?: string | null
          p_season_id?: string | null
        }
        Returns: {
          bucket_date: string
          player_registered: number | null
          player_pending_review: number | null
          player_rejected: number | null
          team_applications: number
          team_approved: number
          team_rejected: number
          team_pending: number
          membership_requests: number
          membership_accepted: number
          membership_rejected: number
          membership_pending: number
        }[]
      }
      get_admin_season_player_club_statistics: {
        Args: { p_season_id: string }
        Returns: Json
      }
      get_admin_season_statistics: {
        Args: { p_season_id: string }
        Returns: Json
      }
      get_admin_stripe_payments: {
        Args: { p_season_id?: string }
        Returns: {
          amount_pence: number
          amount_refunded_pence: number
          created_at: string
          currency: string
          fixture_id: string
          gameweek: number
          net_amount_pence: number
          paid_at: string
          payment_record_id: string
          player_name: string
          scheduled_at: string
          season_id: string
          season_name: string
          status: Database["public"]["Enums"]["payment_status"]
          stripe_fee_pence: number
          team_name: string
        }[]
      }
      get_admin_team_fixture_payment_queue: {
        Args: { p_season_id?: string }
        Returns: { amount_pence: number; deadline_at: string; fixture_id: string; gameweek: number; grace_ends_at: string; obligation_id: string; opponent_name: string; paid_at: string; refund_status: string; scheduled_at: string; season_id: string; season_name: string; season_team_id: string; status: string; strike_created_at: string; team_name: string }[]
      }
      get_admin_team_sheets: {
        Args: never
        Returns: {
          competition_format: Database["public"]["Enums"]["competition_format"]
          fixture_id: string
          gameweek: number
          is_locked: boolean
          opponent_name: string
          players: Json
          roster: Json
          scheduled_at: string
          season_team_id: string
          submitted_at: string
          team_name: string
          team_sheet_id: string
        }[]
      }
      get_admin_team_sheets_contextual: {
        Args: {
          p_league_id?: string
          p_location_id?: string
          p_season_id?: string
        }
        Returns: {
          competition_format: Database["public"]["Enums"]["competition_format"]
          fixture_id: string
          gameweek: number
          is_locked: boolean
          opponent_name: string
          players: Json
          roster: Json
          scheduled_at: string
          season_team_id: string
          submitted_at: string
          team_name: string
          team_sheet_id: string
        }[]
      }
      get_admin_user_growth: {
        Args: {
          p_from_date?: string | null
          p_to_date?: string | null
          p_location_id?: string | null
          p_league_id?: string | null
          p_season_id?: string | null
        }
        Returns: {
          bucket_date: string
          account_signups: number | null
          player_registrations: number
          team_applications: number
          team_approvals: number
        }[]
      }
      get_captain_availability: {
        Args: never
        Returns: {
          fixture_id: string
          gameweek: number
          is_available: boolean
          player_name: string
          responded_at: string
          response_note: string
          scheduled_at: string
          season_team_id: string
          team_name: string
        }[]
      }
      get_captain_dashboard: {
        Args: never
        Returns: {
          is_captain: boolean
          membership_id: string
          membership_status: string
          player_name: string
          requested_at: string
          season_team_id: string
          squad_number: number
          team_name: string
        }[]
      }
      get_captain_fixtures: {
        Args: never
        Returns: {
          competition_format: string
          fixture_id: string
          gameweek: number
          opponent_name: string
          scheduled_at: string
          season_team_id: string
          team_name: string
        }[]
      }
      get_captain_motm_nomination_options: {
        Args: Record<PropertyKey, never>
        Returns: {
          fixture_id: string
          season_team_id: string
          team_name: string
          opponent_name: string
          gameweek: number
          scheduled_at: string
          deadline_at: string
          nomination_id: string | null
          nominated_competition_player_id: string | null
          nominated_player_name: string | null
          can_nominate: boolean
          eligible_players: Json
        }[]
      }
      get_captain_team_fixture_payments: {
        Args: never
        Returns: {
          amount_pence: number
          deadline_at: string
          fixture_id: string
          gameweek: number
          grace_ends_at: string
          obligation_id: string
          opponent_name: string
          paid_at: string
          scheduled_at: string
          season_team_id: string
          status: string
          team_name: string
        }[]
      }
      get_captain_team_sheet: {
        Args: { p_fixture_id: string }
        Returns: {
          draft_saved_at: string
          goalkeeper_membership_id: string
          is_locked: boolean
          season_team_id: string
          starters: string[]
          submitted_at: string
          substitutes: string[]
        }[]
      }
      get_captain_transfer_requests: {
        Args: never
        Returns: {
          destination_season_team_id: string
          destination_team_name: string
          id: string
          is_emergency: boolean
          league_name: string
          player_name: string
          reason: string
          requested_at: string
          season_name: string
          source_team_name: string
          status: string
          target_fixture_id: string | null
          user_id: string
        }[]
      }
      get_finance_ledger: {
        Args: { p_season_id?: string; p_team_id?: string }
        Returns: {
          amount_pence: number
          created_at: string
          created_by: string
          description: string
          due_at: string
          entry_type: string
          fixture_id: string
          gameweek: number
          id: string
          notes: string
          occurred_at: string
          payment_method: string
          reference: string
          season_id: string
          season_name: string
          season_team_id: string
          team_balance_pence: number
          team_name: string
        }[]
      }
      get_finance_options: {
        Args: never
        Returns: {
          league_name: string
          season_id: string
          season_name: string
          season_status: string
          team_id: string
          team_name: string
        }[]
      }
      get_finance_summary: {
        Args: { p_season_id?: string }
        Returns: {
          charges_pence: number
          credits_pence: number
          fines_pence: number
          outstanding_pence: number
          payments_pence: number
          refunds_pence: number
          season_id: string
          season_name: string
          teams_with_entries: number
        }[]
      }
      get_message_history: {
        Args: { p_before?: string; p_conversation_id: string; p_limit?: number }
        Returns: { body: string; conversation_id: string; created_at: string; is_hidden: boolean; message_id: string; message_type: string; sender_id: string; sender_name: string }[]
      }
      get_my_blocked_message_users: {
        Args: Record<PropertyKey, never>
        Returns: { blocked_at: string; display_name: string; user_id: string }[]
      }
      get_my_fixture_payments: {
        Args: never
        Returns: {
          amount_pence: number
          amount_refunded_pence: number
          created_at: string
          currency: string
          fixture_id: string
          gameweek: number
          paid_at: string
          payment_record_id: string
          scheduled_at: string
          season_team_id: string
          status: Database["public"]["Enums"]["payment_status"]
        }[]
      }
      get_my_guardian_consent_status: {
        Args: never
        Returns: {
          guardian_email: string
          guardian_full_name: string
          player_date_of_birth: string
          review_reason: string | null
          reviewed_at: string | null
          status: string
          verified_at: string | null
          withdrawn_at: string | null
        }[]
      }
      get_my_message_conversations: {
        Args: { p_limit?: number }
        Returns: { conversation_id: string; created_at: string; kind: string; last_message_at: string; last_message_body: string; last_message_id: string; last_message_sender_id: string; other_participant_last_read_at: string; other_participant_name: string; other_participant_user_id: string; participant_count: number; read_by_count: number; season_team_id: string; title: string; unread_count: number; updated_at: string }[]
      }
      get_my_notification_preferences: {
        Args: never
        Returns: {
          email_enabled: boolean
          in_app_enabled: boolean
          sms_consent_revoked_at: string | null
          sms_consent_version: string | null
          sms_consented_at: string | null
          sms_enabled: boolean
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "notification_preferences"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      get_my_player_account_retention_status: {
        Args: never
        Returns: { account_closed_at: string | null; account_retention_status: string; archive_expires_at: string | null }[]
      }
      get_my_player_motm_awards: {
        Args: { p_season_id?: string | null }
        Returns: Json
      }
      get_my_player_statistics: {
        Args: { p_season_id: string }
        Returns: Json
      }
      get_my_referee_assignments: {
        Args: Record<PropertyKey, never>
        Returns: { assigned_at: string; assignment_id: string; assignment_role: string; away_team_name: string; fixture_id: string; fixture_number: number; fixture_status: Database["public"]["Enums"]["fixture_status"]; gameweek: number; home_team_name: string; scheduled_at: string; venue_name: string }[]
      }
      get_my_referee_connect_status: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      get_my_referee_fixture_report_options: {
        Args: { p_fixture_id: string }
        Returns: Json
      }
      get_my_referee_portal_state: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      get_my_team_request_statuses: {
        Args: never
        Returns: {
          created_at: string
          is_captain: boolean
          is_transfer_request: boolean
          membership_id: string
          membership_status: string
          season_id: string
          season_name: string
          season_team_id: string
          team_name: string
          team_registration_status: string
        }[]
      }
      get_my_transfer_destinations: {
        Args: never
        Returns: {
          destination_team_id: string
          destination_team_name: string
          emergency_window: boolean
          league_id: string
          league_name: string
          season_id: string
          season_name: string
          source_membership_id: string
          source_team_id: string
          source_team_name: string
          target_fixture_id: string | null
          target_fixture_scheduled_at: string | null
        }[]
      }
      get_my_transfer_requests: {
        Args: never
        Returns: {
          destination_team_name: string
          id: string
          is_emergency: boolean
          reason: string
          requested_at: string
          resolution_reason: string | null
          resolved_at: string | null
          season_name: string
          source_team_name: string
          status: string
        }[]
      }
      get_player_account_reactivation_target: {
        Args: { p_token_hash: string }
        Returns: string
      }
      get_public_announcement_status: {
        Args: never
        Returns: boolean
      }
      get_public_season_club_leaders: {
        Args: { p_season_id: string }
        Returns: {
          competition_player_id: string
          player_name: string
          season_team_id: string
          team_name: string
          motm_awards: number
          appearances: number
        }[]
      }
      get_public_season_team_squad_counts: {
        Args: { p_season_id: string }
        Returns: { registered_players: number; season_team_id: string }[]
      }
      get_public_team_recruitment_status: {
        Args: never
        Returns: boolean
      }
      get_public_team_squad: {
        Args: { p_season_team_id: string }
        Returns: { appearances: number; assists: number; clean_sheets: number; competition_player_id: string; goals: number; is_captain: boolean; motm_awards: number; player_name: string; squad_number: number }[]
      }
      handover_team_captain: {
        Args: { p_new_captain_membership_id: string; p_season_team_id: string }
        Returns: {
          created_at: string
          id: string
          is_captain: boolean
          joined_at: string | null
          left_at: string | null
          season_team_id: string
          squad_number: number | null
          status: Database["public"]["Enums"]["membership_status"]
          transfer_request_id: string | null
          voluntarily_left_at: string | null
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "team_memberships"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      has_finance_access: { Args: never; Returns: boolean }
      has_global_admin_role: {
        Args: Record<PropertyKey, never>
        Returns: boolean
      }
      has_platform_role: { Args: never; Returns: boolean }
      hash_guardian_consent_token: {
        Args: { p_token: string }
        Returns: string
      }
      is_active_team_captain: {
        Args: { p_season_team_id: string }
        Returns: boolean
      }
      is_active_team_member: {
        Args: { p_season_team_id: string }
        Returns: boolean
      }
      is_platform_feature_enabled: {
        Args: { p_feature_key: string }
        Returns: boolean
      }
      leave_team_membership: {
        Args: { p_membership_id: string }
        Returns: {
          created_at: string
          id: string
          is_captain: boolean
          joined_at: string | null
          left_at: string | null
          season_team_id: string
          squad_number: number | null
          status: Database["public"]["Enums"]["membership_status"]
          transfer_request_id: string | null
          voluntarily_left_at: string | null
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "team_memberships"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      mark_message_conversation_read: {
        Args: { p_conversation_id: string }
        Returns: undefined
      }
      mark_notification_event_unconfirmed: {
        Args: { p_error: string; p_event_id: string }
        Returns: {
          attempt_count: number
          channel: string
          created_at: string
          dedupe_key: string | null
          event_type: string
          held_at: string | null
          held_by: string | null
          hold_reason: string | null
          id: string
          last_attempt_at: string | null
          last_error: string | null
          locked_at: string | null
          manual_retry_used: boolean
          next_attempt_at: string
          payload: Json
          provider_reference: string | null
          read_at: string | null
          sent_at: string | null
          status: string
          unconfirmed_at: string | null
          updated_at: string
          user_id: string | null
        }
        SetofOptions: {
          from: "*"
          to: "notification_events"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      mark_notification_read: {
        Args: { p_event_id: string }
        Returns: undefined
      }
      mark_stale_notification_events_unconfirmed: {
        Args: never
        Returns: number
      }
      message_actor_is_active: {
        Args: { p_user_id: string }
        Returns: boolean
      }
      normalize_player_phone: {
        Args: { p_phone: string }
        Returns: string
      }
      open_play_uk_date: {
        Args: { p_instant: string }
        Returns: string
      }
      process_team_fixture_payment_deadlines: {
        Args: { p_as_of?: string }
        Returns: number
      }
      record_referee_payout_transfer_failure: {
        Args: { p_failure_reason: string; p_payout_id: string; p_payout_type: string; p_stripe_transfer_id?: string; p_transfer_reversed?: boolean }
        Returns: string
      }
      record_referee_payout_transfer_success: {
        Args: { p_amount_pence: number; p_currency: string; p_destination_account_id: string; p_payout_id: string; p_payout_type: string; p_stripe_transfer_id: string }
        Returns: string
      }
      record_team_fixture_payment_refund_result: {
        Args: { p_failure_reason?: string; p_refund_id: string; p_stripe_refund_id?: string; p_succeeded: boolean }
        Returns: string
      }
      record_team_fixture_payment_success: {
        Args: { p_obligation_id: string; p_paid_at: string; p_stripe_payment_intent_id: string }
        Returns: string
      }
      register_player: {
        Args: {
          p_date_of_birth: string
          p_email: string
          p_full_name: string
          p_phone: string
        }
        Returns: {
          banned_at: string | null
          banned_reason: string | null
          created_at: string
          date_of_birth: string
          email: string
          full_name: string
          id: string
          is_banned: boolean
          is_genuine: boolean
          phone: string
          registration_status: Database["public"]["Enums"]["player_registration_status"]
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "players"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      register_team: {
        Args: {
          p_primary_colour?: string
          p_season_id: string
          p_secondary_colour?: string
          p_team_name: string
        }
        Returns: {
          approved_at: string | null
          approved_by: string | null
          badge_path: string | null
          created_at: string
          id: string
          name: string
          primary_colour: string | null
          registration_status: Database["public"]["Enums"]["registration_status"]
          season_id: string
          secondary_colour: string | null
          slug: string
          team_id: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "season_teams"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      release_referee_payout_transfer_job: {
        Args: { p_delay_seconds?: number; p_job_id: string; p_lock_token: string; p_reason: string }
        Returns: boolean
      }
      report_message: {
        Args: { p_message_id: string; p_reason: string }
        Returns: string
      }
      request_player_account_reactivation: {
        Args: { p_email: string; p_token_hash: string }
        Returns: { email: string | null; user_id: string }[]
      }
      request_player_guardian_consent: {
        Args: {
          p_player_user_id: string
          p_guardian_email: string
          p_guardian_full_name: string
          p_player_date_of_birth: string
          p_verification_token_hash: string
          p_withdrawal_token_hash: string
        }
        Returns: { requested_at: string; status: string }[]
      }
      request_player_transfer: {
        Args: {
          p_destination_season_team_id: string
          p_reason: string
        }
        Returns: {
          created_at: string
          destination_season_team_id: string
          id: string
          is_emergency: boolean
          league_id: string
          reason: string
          requested_at: string
          resolution_reason: string | null
          resolved_at: string | null
          resolved_by: string | null
          source_membership_id: string | null
          source_season_team_id: string
          status: string
          target_fixture_id: string | null
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "player_transfer_requests"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      request_team_membership: {
        Args: { p_season_team_id: string }
        Returns: {
          created_at: string
          id: string
          is_captain: boolean
          joined_at: string | null
          left_at: string | null
          season_team_id: string
          squad_number: number | null
          status: Database["public"]["Enums"]["membership_status"]
          transfer_request_id: string | null
          voluntarily_left_at: string | null
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "team_memberships"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      resolve_player_registration_review: {
        Args: { p_decision: string; p_player_id: string; p_reason?: string }
        Returns: {
          banned_at: string | null
          banned_reason: string | null
          created_at: string
          date_of_birth: string
          email: string
          full_name: string
          id: string
          is_banned: boolean
          is_genuine: boolean
          phone: string
          registration_status: Database["public"]["Enums"]["player_registration_status"]
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "players"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      resolve_player_transfer_request: {
        Args: { p_decision: string; p_reason: string; p_request_id: string }
        Returns: {
          created_at: string
          destination_season_team_id: string
          id: string
          is_emergency: boolean
          league_id: string
          reason: string
          requested_at: string
          resolution_reason: string | null
          resolved_at: string | null
          resolved_by: string | null
          source_membership_id: string | null
          source_season_team_id: string
          status: string
          target_fixture_id: string | null
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "player_transfer_requests"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      resolve_team_membership_request: {
        Args: { p_decision: string; p_membership_id: string }
        Returns: {
          created_at: string
          id: string
          is_captain: boolean
          joined_at: string | null
          left_at: string | null
          season_team_id: string
          squad_number: number | null
          status: Database["public"]["Enums"]["membership_status"]
          transfer_request_id: string | null
          voluntarily_left_at: string | null
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "team_memberships"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      resolve_team_registration: {
        Args: {
          p_decision: string
          p_reason?: string
          p_season_team_id: string
        }
        Returns: {
          approved_at: string | null
          approved_by: string | null
          badge_path: string | null
          created_at: string
          id: string
          name: string
          primary_colour: string | null
          registration_status: Database["public"]["Enums"]["registration_status"]
          season_id: string
          secondary_colour: string | null
          slug: string
          team_id: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "season_teams"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      review_referee_application: {
        Args: { p_application_id: string; p_decision: string; p_reason: string }
        Returns: undefined
      }
      round_robin_fixture_settings_hash: {
        Args: { p_first_matchday_date: string; p_season_id: string }
        Returns: string
      }
      save_admin_context_preference: {
        Args: {
          p_league_id?: string
          p_location_id?: string
          p_season_id?: string
        }
        Returns: Json
      }
      save_team_sheet_draft: {
        Args: {
          p_fixture_id: string
          p_goalkeeper_membership_id?: string
          p_season_team_id: string
          p_starters: string[]
          p_substitutes?: string[]
        }
        Returns: {
          draft_saved_at: string | null
          fixture_id: string
          id: string
          is_locked: boolean
          season_team_id: string
          submitted_at: string | null
          submitted_by: string
        }
        SetofOptions: {
          from: "*"
          to: "fixture_team_sheets"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      search_message_recipients: {
        Args: { p_limit?: number; p_query: string }
        Returns: { display_name: string; shared_team_name: string; user_id: string }[]
      }
      season_joint_leaders: {
        Args: { p_season_id: string }
        Returns: string[]
      }
      season_league_points: {
        Args: { p_season_id: string }
        Returns: { points: number; team_id: string }[]
      }
      send_message: {
        Args: { p_body: string; p_conversation_id: string; p_message_type?: string }
        Returns: string
      }
      set_referee_membership_status: {
        Args: { p_reason: string; p_status: string; p_user_id: string }
        Returns: undefined
      }
      set_team_fixture_payment_checkout_session: {
        Args: { p_attempt: number; p_obligation_id: string; p_session_id: string }
        Returns: boolean
      }
      set_team_squad_number: {
        Args: { p_membership_id: string; p_squad_number?: number }
        Returns: {
          created_at: string
          id: string
          is_captain: boolean
          joined_at: string | null
          left_at: string | null
          season_team_id: string
          squad_number: number | null
          status: Database["public"]["Enums"]["membership_status"]
          transfer_request_id: string | null
          voluntarily_left_at: string | null
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "team_memberships"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      submit_fixture_motm_nomination: {
        Args: { p_fixture_id: string; p_competition_player_id: string }
        Returns: string
      }
      submit_referee_application: {
        Args: { p_additional_notes: string; p_availability: Json; p_contact_phone: string; p_experience_summary: string; p_preferred_location_ids: string[]; p_qualifications: string[] }
        Returns: string
      }
      submit_referee_match_report: {
        Args: { p_away_score: number; p_away_scorers?: string[]; p_away_substitute_appearances?: string[]; p_disciplinary_events?: Json; p_fixture_id: string; p_home_score: number; p_home_scorers?: string[]; p_home_substitute_appearances?: string[]; p_match_write_up?: string }
        Returns: string
      }
      submit_team_sheet: {
        Args: {
          p_fixture_id: string
          p_goalkeeper_membership_id?: string
          p_season_team_id: string
          p_starters: string[]
          p_substitutes?: string[]
        }
        Returns: {
          draft_saved_at: string | null
          fixture_id: string
          id: string
          is_locked: boolean
          season_team_id: string
          submitted_at: string | null
          submitted_by: string
        }
        SetofOptions: {
          from: "*"
          to: "fixture_team_sheets"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      sync_referee_connect_account: {
        Args: { p_charges_enabled: boolean; p_details_submitted: boolean; p_disabled_reason: string; p_payouts_enabled: boolean; p_referee_user_id: string; p_requirements_due: Json; p_stripe_account_id: string; p_stripe_event_created_at?: string; p_transfers_enabled: boolean }
        Returns: string
      }
      unblock_message_user: {
        Args: { p_blocked_user_id: string }
        Returns: undefined
      }
      update_my_notification_preferences: {
        Args: {
          p_email_enabled: boolean
          p_in_app_enabled: boolean
          p_sms_enabled: boolean
        }
        Returns: {
          email_enabled: boolean
          in_app_enabled: boolean
          sms_consent_revoked_at: string | null
          sms_consent_version: string | null
          sms_consented_at: string | null
          sms_enabled: boolean
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "notification_preferences"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      verify_player_guardian_consent: {
        Args: { p_token: string }
        Returns: string
      }
      withdraw_player_guardian_consent: {
        Args: { p_token: string }
        Returns: string
      }


    }
    Enums: {
      competition_format: "six_a_side" | "seven_a_side"
      fixture_status:
        | "scheduled"
        | "in_progress"
        | "completed"
        | "postponed"
        | "cancelled"
      lineup_role: "starter" | "substitute"
      membership_status:
        | "pending"
        | "active"
        | "suspended"
        | "left"
        | "rejected"
      payment_status:
        | "pending"
        | "processing"
        | "paid"
        | "failed"
        | "refunded"
        | "cancelled"
        | "partially_refunded"
      player_registration_status: "registered" | "pending_review" | "rejected"
      registration_status: "pending" | "approved" | "rejected" | "withdrawn"
      season_status:
        | "draft"
        | "registration_open"
        | "active"
        | "completed"
        | "archived"
      transfer_status: "pending" | "approved" | "rejected" | "cancelled"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      competition_format: ["six_a_side", "seven_a_side"],
      fixture_status: [
        "scheduled",
        "in_progress",
        "completed",
        "postponed",
        "cancelled",
      ],
      lineup_role: ["starter", "substitute"],
      membership_status: ["pending", "active", "suspended", "left", "rejected"],
      payment_status: [
        "pending",
        "processing",
        "paid",
        "failed",
        "refunded",
        "cancelled",
        "partially_refunded",
      ],
      player_registration_status: ["registered", "pending_review", "rejected"],
      registration_status: ["pending", "approved", "rejected", "withdrawn"],
      season_status: [
        "draft",
        "registration_open",
        "active",
        "completed",
        "archived",
      ],
      transfer_status: ["pending", "approved", "rejected", "cancelled"],
    },
  },
} as const
