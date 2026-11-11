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
        Insert: {
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
        }
        Update: {
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
            referencedRelation: "locations"
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
      player_registration_reviews: {
        Row: {
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
        Insert: {
          created_at?: string
          ends_on?: string | null
          id?: string
          is_public?: boolean
          league_id: string
          name: string
          registration_closes_at?: string | null
          registration_opens_at?: string | null
          season_number?: number | null
          starts_on?: string | null
          status?: Database["public"]["Enums"]["season_status"]
          updated_at?: string
        }
        Update: {
          created_at?: string
          ends_on?: string | null
          id?: string
          is_public?: boolean
          league_id?: string
          name?: string
          registration_closes_at?: string | null
          registration_opens_at?: string | null
          season_number?: number | null
          starts_on?: string | null
          status?: Database["public"]["Enums"]["season_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "seasons_league_id_fkey"
            columns: ["league_id"]
            isOneToOne: false
            referencedRelation: "leagues"
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
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
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
      admin_set_player_retention_hold: {
        Args: { p_hold: boolean; p_reason: string; p_user_id: string }
        Returns: boolean
      }
      admin_close_inactive_player_account: {
        Args: { p_user_id: string }
        Returns: boolean
      }
      admin_prepare_player_account_erasure: {
        Args: { p_user_id: string }
        Returns: boolean
      }
      admin_list_expired_player_account_archives: {
        Args: never
        Returns: { archive_expires_at: string; email: string | null; user_id: string }[]
      }
      admin_list_inactive_player_accounts: {
        Args: never
        Returns: { email: string | null; last_sign_in_at: string; user_id: string }[]
      }
      admin_mark_player_account_erasure_due: {
        Args: { p_user_id: string }
        Returns: boolean
      }
      complete_player_account_reactivation: {
        Args: { p_token_hash: string; p_user_id: string }
        Returns: boolean
      }
      get_my_player_account_retention_status: {
        Args: never
        Returns: { account_closed_at: string | null; account_retention_status: string; archive_expires_at: string | null }[]
      }
      get_player_account_reactivation_target: {
        Args: { p_token_hash: string }
        Returns: string
      }
      request_player_account_reactivation: {
        Args: { p_email: string; p_token_hash: string }
        Returns: { email: string | null; user_id: string }[]
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
      admin_review_guardian_consent: {
        Args: { p_consent_id: string; p_decision: string; p_reason: string }
        Returns: string
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
      verify_player_guardian_consent: {
        Args: { p_token: string }
        Returns: string
      }
      withdraw_player_guardian_consent: {
        Args: { p_token: string }
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
      admin_search_location_admin_candidates: {
        Args: { p_query: string }
        Returns: {
          display_name: string
          email: string
          user_id: string
        }[]
      }
      get_my_referee_connect_status: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      claim_referee_payout_transfer: {
        Args: { p_payout_type: string; p_payout_id: string }
        Returns: Json
      }
      admin_get_referee_payout_transfer_history: {
        Args: { p_payout_type: string; p_payout_id: string }
        Returns: {
          attempt_number: number; status: string; amount_pence: number;
          stripe_transfer_id: string | null; failure_reason: string | null; created_at: string;
        }[]
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
      admin_get_approved_referee_report_correction_options: {
        Args: { p_report_id: string }
        Returns: Json
      }
      admin_postpone_gameweek_weather: {
        Args: {
          p_gameweek: number
          p_reason: string
          p_replacement_date: string
          p_season_id: string
        }
        Returns: Json
      }
      get_admin_weather_postponements: {
        Args: { p_season_id?: string | null }
        Returns: {
          created_at: string
          fixture_count: number
          original_gameweek: number
          postponement_id: string
          reason: string
          refunds_completed: number
          refunds_failed: number
          refunds_pending: number
          replacement_date: string
          season_id: string
          season_name: string
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
      assert_admin_location_context: {
        Args: { p_location_id: string }
        Returns: undefined
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
      create_player_fixture_payment: {
        Args: { p_fixture_id: string; p_season_team_id: string }
        Returns: {
          already_paid: boolean
          amount_pence: number
          currency: string
          payment_record_id: string
        }[]
      }
      dispatch_notification_worker: { Args: never; Returns: number }
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
      get_admin_competition_setup: { Args: never; Returns: Json }
      get_admin_context_preference: { Args: never; Returns: Json }
      get_admin_contextual_fixtures: {
        Args: {
          p_league_id?: string
          p_location_id?: string
          p_season_id?: string
        }
        Returns: {
          away_score: number
          away_team_id: string
          away_team_name: string
          fixture_number: number
          gameweek: number
          home_score: number
          home_team_id: string
          home_team_name: string
          id: string
          notes: string
          scheduled_at: string
          season_id: string
          season_name: string
          status: string
          venue_id: string
          venue_name: string
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
      get_admin_season_statistics: {
        Args: { p_season_id: string }
        Returns: Json
      }
      get_admin_season_player_club_statistics: {
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
      get_my_player_statistics: {
        Args: { p_season_id: string }
        Returns: Json
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
      has_platform_role: { Args: never; Returns: boolean }
      is_active_team_captain: {
        Args: { p_season_team_id: string }
        Returns: boolean
      }
      is_active_team_member: {
        Args: { p_season_team_id: string }
        Returns: boolean
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
      admin_set_platform_feature_flag: {
        Args: { p_enabled: boolean; p_feature_key: string; p_reason: string }
        Returns: Database["public"]["Tables"]["platform_feature_flags"]["Row"]
      }
      get_public_announcement_status: {
        Args: never
        Returns: boolean
      }
      get_public_team_recruitment_status: {
        Args: never
        Returns: boolean
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
