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
          created_at: string
          id: string
          role: Database["public"]["Enums"]["lineup_role"]
          squad_number_snapshot: number | null
          team_sheet_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          role: Database["public"]["Enums"]["lineup_role"]
          squad_number_snapshot?: number | null
          team_sheet_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["lineup_role"]
          squad_number_snapshot?: number | null
          team_sheet_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fixture_team_sheet_players_team_sheet_id_fkey"
            columns: ["team_sheet_id"]
            isOneToOne: false
            referencedRelation: "fixture_team_sheets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fixture_team_sheet_players_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      fixture_team_sheets: {
        Row: {
          fixture_id: string
          id: string
          is_locked: boolean
          season_team_id: string
          submitted_at: string
          submitted_by: string
        }
        Insert: {
          fixture_id: string
          id?: string
          is_locked?: boolean
          season_team_id: string
          submitted_at?: string
          submitted_by: string
        }
        Update: {
          fixture_id?: string
          id?: string
          is_locked?: boolean
          season_team_id?: string
          submitted_at?: string
          submitted_by?: string
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
      notification_events: {
        Row: {
          channel: string
          created_at: string
          event_type: string
          id: string
          payload: Json
          provider_reference: string | null
          sent_at: string | null
          status: string
          user_id: string | null
        }
        Insert: {
          channel: string
          created_at?: string
          event_type: string
          id?: string
          payload?: Json
          provider_reference?: string | null
          sent_at?: string | null
          status?: string
          user_id?: string | null
        }
        Update: {
          channel?: string
          created_at?: string
          event_type?: string
          id?: string
          payload?: Json
          provider_reference?: string | null
          sent_at?: string | null
          status?: string
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
      payment_records: {
        Row: {
          amount_pence: number
          created_at: string
          currency: string
          fee_snapshot: Json
          fixture_id: string | null
          id: string
          paid_at: string | null
          refunded_at: string | null
          season_team_id: string
          status: Database["public"]["Enums"]["payment_status"]
          stripe_checkout_session_id: string | null
          stripe_payment_intent_id: string | null
          updated_at: string
        }
        Insert: {
          amount_pence: number
          created_at?: string
          currency?: string
          fee_snapshot: Json
          fixture_id?: string | null
          id?: string
          paid_at?: string | null
          refunded_at?: string | null
          season_team_id: string
          status?: Database["public"]["Enums"]["payment_status"]
          stripe_checkout_session_id?: string | null
          stripe_payment_intent_id?: string | null
          updated_at?: string
        }
        Update: {
          amount_pence?: number
          created_at?: string
          currency?: string
          fee_snapshot?: Json
          fixture_id?: string | null
          id?: string
          paid_at?: string | null
          refunded_at?: string | null
          season_team_id?: string
          status?: Database["public"]["Enums"]["payment_status"]
          stripe_checkout_session_id?: string | null
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
      players: {
        Row: {
          banned_at: string | null
          banned_reason: string | null
          created_at: string
          date_of_birth: string
          email: string
          full_name: string
          id: string
          is_banned: boolean
          phone: string
          registration_status: Database["public"]["Enums"]["player_registration_status"]
          updated_at: string
          user_id: string
        }
        Insert: {
          banned_at?: string | null
          banned_reason?: string | null
          created_at?: string
          date_of_birth: string
          email: string
          full_name: string
          id?: string
          is_banned?: boolean
          phone: string
          registration_status: Database["public"]["Enums"]["player_registration_status"]
          updated_at?: string
          user_id: string
        }
        Update: {
          banned_at?: string | null
          banned_reason?: string | null
          created_at?: string
          date_of_birth?: string
          email?: string
          full_name?: string
          id?: string
          is_banned?: boolean
          phone?: string
          registration_status?: Database["public"]["Enums"]["player_registration_status"]
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      profiles: {
        Row: {
          avatar_path: string | null
          created_at: string
          date_of_birth: string | null
          display_name: string | null
          emergency_contact_name: string | null
          emergency_contact_phone: string | null
          first_name: string | null
          id: string
          last_name: string | null
          phone: string | null
          preferred_position: string | null
          updated_at: string
        }
        Insert: {
          avatar_path?: string | null
          created_at?: string
          date_of_birth?: string | null
          display_name?: string | null
          emergency_contact_name?: string | null
          emergency_contact_phone?: string | null
          first_name?: string | null
          id: string
          last_name?: string | null
          phone?: string | null
          preferred_position?: string | null
          updated_at?: string
        }
        Update: {
          avatar_path?: string | null
          created_at?: string
          date_of_birth?: string | null
          display_name?: string | null
          emergency_contact_name?: string | null
          emergency_contact_phone?: string | null
          first_name?: string | null
          id?: string
          last_name?: string | null
          phone?: string | null
          preferred_position?: string | null
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
          reason: string | null
          season_id: string
          team_fee_pence: number
        }
        Insert: {
          changed_by?: string | null
          created_at?: string
          effective_from_gameweek?: number
          id?: string
          reason?: string | null
          season_id: string
          team_fee_pence: number
        }
        Update: {
          changed_by?: string | null
          created_at?: string
          effective_from_gameweek?: number
          id?: string
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
      membership_status: "pending" | "active" | "suspended" | "left"
      payment_status:
        | "pending"
        | "processing"
        | "paid"
        | "failed"
        | "refunded"
        | "cancelled"
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
      membership_status: ["pending", "active", "suspended", "left"],
      payment_status: [
        "pending",
        "processing",
        "paid",
        "failed",
        "refunded",
        "cancelled",
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
