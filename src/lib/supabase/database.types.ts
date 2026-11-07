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
      fixture_goal_records: {
        Row: {
          created_at: string
          created_by: string
          fixture_id: string
          id: string
          scorer_user_id: string
          season_team_id: string
          void_reason: string | null
          voided_at: string | null
          voided_by: string | null
        }
        Insert: {
          created_at?: string
          created_by: string
          fixture_id: string
          id?: string
          scorer_user_id: string
          season_team_id: string
          void_reason?: string | null
          voided_at?: string | null
          voided_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string
          fixture_id?: string
          id?: string
          scorer_user_id?: string
          season_team_id?: string
          void_reason?: string | null
          voided_at?: string | null
          voided_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fixture_goal_records_fixture_id_fkey"
            columns: ["fixture_id"]
            isOneToOne: false
            referencedRelation: "fixtures"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fixture_goal_records_scorer_user_id_fkey"
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
          created_at: string
          id: string
          is_goalkeeper: boolean
          role: Database["public"]["Enums"]["lineup_role"]
          squad_number_snapshot: number | null
          team_sheet_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          is_goalkeeper?: boolean
          role: Database["public"]["Enums"]["lineup_role"]
          squad_number_snapshot?: number | null
          team_sheet_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          is_goalkeeper?: boolean
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
          draft_saved_at: string | null
          fixture_id: string
          id: string
          is_locked: boolean
          season_team_id: string
          submitted_at: string | null
          submitted_by: string
        }
        Insert: {
          draft_saved_at?: string | null
          fixture_id: string
          id?: string
          is_locked?: boolean
          season_team_id: string
          submitted_at?: string | null
          submitted_by: string
        }
        Update: {
          draft_saved_at?: string | null
          fixture_id?: string
          id?: string
          is_locked?: boolean
          season_team_id?: string
          submitted_at?: string | null
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
          is_genuine: boolean
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
          is_genuine?: boolean
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
          is_genuine?: boolean
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
      get_admin_competition_setup: { Args: never; Returns: Json }
      get_admin_dashboard: { Args: never; Returns: Json }
      get_admin_fixture_scorer_options: {
        Args: { p_fixture_id: string }
        Returns: Json
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
      get_admin_season_statistics: {
        Args: { p_season_id: string }
        Returns: Json
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
