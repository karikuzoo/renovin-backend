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
      app_settings: {
        Row: {
          description: string | null
          key: string
          updated_at: string
          updated_by: string | null
          value: Json
        }
        Insert: {
          description?: string | null
          key: string
          updated_at?: string
          updated_by?: string | null
          value: Json
        }
        Update: {
          description?: string | null
          key?: string
          updated_at?: string
          updated_by?: string | null
          value?: Json
        }
        Relationships: [
          {
            foreignKeyName: "app_settings_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      approvals: {
        Row: {
          decided_at: string
          decided_by: string
          decision: Database["public"]["Enums"]["approval_decision"]
          id: string
          note: string | null
          project_id: string
          rab_data: Json | null
          rab_id: string | null
        }
        Insert: {
          decided_at?: string
          decided_by: string
          decision: Database["public"]["Enums"]["approval_decision"]
          id?: string
          note?: string | null
          project_id: string
          rab_data?: Json | null
          rab_id?: string | null
        }
        Update: {
          decided_at?: string
          decided_by?: string
          decision?: Database["public"]["Enums"]["approval_decision"]
          id?: string
          note?: string | null
          project_id?: string
          rab_data?: Json | null
          rab_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "approvals_decided_by_fkey"
            columns: ["decided_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "approvals_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "approvals_rab_id_fkey"
            columns: ["rab_id"]
            isOneToOne: false
            referencedRelation: "rabs"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_logs: {
        Row: {
          action: string
          actor_id: string | null
          created_at: string
          id: number
          new_data: Json | null
          old_data: Json | null
          record_id: string | null
          table_name: string
        }
        Insert: {
          action: string
          actor_id?: string | null
          created_at?: string
          id?: never
          new_data?: Json | null
          old_data?: Json | null
          record_id?: string | null
          table_name: string
        }
        Update: {
          action?: string
          actor_id?: string | null
          created_at?: string
          id?: never
          new_data?: Json | null
          old_data?: Json | null
          record_id?: string | null
          table_name?: string
        }
        Relationships: []
      }
      conversations: {
        Row: {
          created_at: string
          customer_id: string
          id: string
          last_message_at: string
          order_code: string | null
          project_id: string | null
          status: Database["public"]["Enums"]["conversation_status"]
        }
        Insert: {
          created_at?: string
          customer_id?: string
          id?: string
          last_message_at?: string
          order_code?: string | null
          project_id?: string | null
          status?: Database["public"]["Enums"]["conversation_status"]
        }
        Update: {
          created_at?: string
          customer_id?: string
          id?: string
          last_message_at?: string
          order_code?: string | null
          project_id?: string | null
          status?: Database["public"]["Enums"]["conversation_status"]
        }
        Relationships: [
          {
            foreignKeyName: "conversations_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conversations_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      furniture_placements: {
        Row: {
          created_at: string
          id: string
          photo_id: string
          product_id: string
          project_id: string
          rendered_url: string | null
          rotation: number
          scale: number
          updated_at: string
          x: number
          y: number
          z_index: number
        }
        Insert: {
          created_at?: string
          id?: string
          photo_id: string
          product_id: string
          project_id: string
          rendered_url?: string | null
          rotation?: number
          scale?: number
          updated_at?: string
          x?: number
          y?: number
          z_index?: number
        }
        Update: {
          created_at?: string
          id?: string
          photo_id?: string
          product_id?: string
          project_id?: string
          rendered_url?: string | null
          rotation?: number
          scale?: number
          updated_at?: string
          x?: number
          y?: number
          z_index?: number
        }
        Relationships: [
          {
            foreignKeyName: "furniture_placements_photo_id_project_id_fkey"
            columns: ["photo_id", "project_id"]
            isOneToOne: false
            referencedRelation: "room_photos"
            referencedColumns: ["id", "project_id"]
          },
          {
            foreignKeyName: "furniture_placements_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "furniture_placements_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      messages: {
        Row: {
          attachment_url: string | null
          body: string
          conversation_id: string
          created_at: string
          id: number
          read_at: string | null
          sender_id: string
        }
        Insert: {
          attachment_url?: string | null
          body: string
          conversation_id: string
          created_at?: string
          id?: never
          read_at?: string | null
          sender_id?: string
        }
        Update: {
          attachment_url?: string | null
          body?: string
          conversation_id?: string
          created_at?: string
          id?: never
          read_at?: string | null
          sender_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "messages_conversation_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "conversations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          body: string | null
          created_at: string
          id: number
          project_id: string | null
          read_at: string | null
          title: string
          type: string
          user_id: string
        }
        Insert: {
          body?: string | null
          created_at?: string
          id?: never
          project_id?: string | null
          read_at?: string | null
          title: string
          type: string
          user_id: string
        }
        Update: {
          body?: string | null
          created_at?: string
          id?: never
          project_id?: string | null
          read_at?: string | null
          title?: string
          type?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      product_categories: {
        Row: {
          active: boolean
          created_at: string
          id: string
          name: string
          slug: string
          sort_order: number
          type: Database["public"]["Enums"]["product_type"]
          updated_at: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          id?: string
          name: string
          slug: string
          sort_order?: number
          type: Database["public"]["Enums"]["product_type"]
          updated_at?: string
        }
        Update: {
          active?: boolean
          created_at?: string
          id?: string
          name?: string
          slug?: string
          sort_order?: number
          type?: Database["public"]["Enums"]["product_type"]
          updated_at?: string
        }
        Relationships: []
      }
      product_internal_prices: {
        Row: {
          price_internal: number
          product_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          price_internal: number
          product_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          price_internal?: number
          product_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "product_internal_prices_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: true
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_internal_prices_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      products: {
        Row: {
          active: boolean
          asset_file_id: string | null
          asset_url: string | null
          category_id: string
          color_hex: string | null
          color_name: string | null
          created_at: string
          created_by: string | null
          depth_cm: number | null
          description: string | null
          height_cm: number | null
          id: string
          image_file_id: string | null
          image_url: string | null
          name: string
          price_customer: number
          sku: string
          type: Database["public"]["Enums"]["product_type"]
          unit: string
          updated_at: string
          width_cm: number | null
        }
        Insert: {
          active?: boolean
          asset_file_id?: string | null
          asset_url?: string | null
          category_id: string
          color_hex?: string | null
          color_name?: string | null
          created_at?: string
          created_by?: string | null
          depth_cm?: number | null
          description?: string | null
          height_cm?: number | null
          id?: string
          image_file_id?: string | null
          image_url?: string | null
          name: string
          price_customer: number
          sku: string
          type: Database["public"]["Enums"]["product_type"]
          unit: string
          updated_at?: string
          width_cm?: number | null
        }
        Update: {
          active?: boolean
          asset_file_id?: string | null
          asset_url?: string | null
          category_id?: string
          color_hex?: string | null
          color_name?: string | null
          created_at?: string
          created_by?: string | null
          depth_cm?: number | null
          description?: string | null
          height_cm?: number | null
          id?: string
          image_file_id?: string | null
          image_url?: string | null
          name?: string
          price_customer?: number
          sku?: string
          type?: Database["public"]["Enums"]["product_type"]
          unit?: string
          updated_at?: string
          width_cm?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "products_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "product_categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          created_at: string
          email: string | null
          full_name: string | null
          id: string
          phone: string | null
          role: Database["public"]["Enums"]["user_role"]
          updated_at: string
        }
        Insert: {
          created_at?: string
          email?: string | null
          full_name?: string | null
          id: string
          phone?: string | null
          role?: Database["public"]["Enums"]["user_role"]
          updated_at?: string
        }
        Update: {
          created_at?: string
          email?: string | null
          full_name?: string | null
          id?: string
          phone?: string | null
          role?: Database["public"]["Enums"]["user_role"]
          updated_at?: string
        }
        Relationships: []
      }
      project_status_history: {
        Row: {
          changed_at: string
          changed_by: string | null
          from_status: Database["public"]["Enums"]["project_status"] | null
          id: number
          note: string | null
          project_id: string
          to_status: Database["public"]["Enums"]["project_status"]
        }
        Insert: {
          changed_at?: string
          changed_by?: string | null
          from_status?: Database["public"]["Enums"]["project_status"] | null
          id?: never
          note?: string | null
          project_id: string
          to_status: Database["public"]["Enums"]["project_status"]
        }
        Update: {
          changed_at?: string
          changed_by?: string | null
          from_status?: Database["public"]["Enums"]["project_status"] | null
          id?: never
          note?: string | null
          project_id?: string
          to_status?: Database["public"]["Enums"]["project_status"]
        }
        Relationships: [
          {
            foreignKeyName: "project_status_history_changed_by_fkey"
            columns: ["changed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_status_history_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      project_status_transitions: {
        Row: {
          allowed_roles: Database["public"]["Enums"]["user_role"][]
          from_status: Database["public"]["Enums"]["project_status"]
          note_required: boolean
          to_status: Database["public"]["Enums"]["project_status"]
        }
        Insert: {
          allowed_roles: Database["public"]["Enums"]["user_role"][]
          from_status: Database["public"]["Enums"]["project_status"]
          note_required?: boolean
          to_status: Database["public"]["Enums"]["project_status"]
        }
        Update: {
          allowed_roles?: Database["public"]["Enums"]["user_role"][]
          from_status?: Database["public"]["Enums"]["project_status"]
          note_required?: boolean
          to_status?: Database["public"]["Enums"]["project_status"]
        }
        Relationships: []
      }
      projects: {
        Row: {
          assigned_admin_id: string | null
          code: string
          created_at: string
          customer_id: string
          final_snapshot_id: string | null
          id: string
          notes: string | null
          room_type: string | null
          status: Database["public"]["Enums"]["project_status"]
          submitted_at: string | null
          title: string
          updated_at: string
        }
        Insert: {
          assigned_admin_id?: string | null
          code?: string
          created_at?: string
          customer_id?: string
          final_snapshot_id?: string | null
          id?: string
          notes?: string | null
          room_type?: string | null
          status?: Database["public"]["Enums"]["project_status"]
          submitted_at?: string | null
          title?: string
          updated_at?: string
        }
        Update: {
          assigned_admin_id?: string | null
          code?: string
          created_at?: string
          customer_id?: string
          final_snapshot_id?: string | null
          id?: string
          notes?: string | null
          room_type?: string | null
          status?: Database["public"]["Enums"]["project_status"]
          submitted_at?: string | null
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "projects_assigned_admin_id_fkey"
            columns: ["assigned_admin_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "projects_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "projects_final_snapshot_fk"
            columns: ["final_snapshot_id"]
            isOneToOne: false
            referencedRelation: "rab_snapshots"
            referencedColumns: ["id"]
          },
        ]
      }
      rab_line_items: {
        Row: {
          created_at: string
          created_by: string | null
          description: string
          id: string
          is_manual: boolean
          item_type: Database["public"]["Enums"]["rab_item_type"]
          placement_id: string | null
          product_id: string | null
          project_id: string
          quantity: number
          rab_id: string
          service_rate_id: string | null
          sort_order: number
          subtotal_customer: number | null
          subtotal_internal: number | null
          unit: string
          unit_price_customer: number
          unit_price_internal: number
          updated_at: string
          wall_paint_id: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          description: string
          id?: string
          is_manual?: boolean
          item_type: Database["public"]["Enums"]["rab_item_type"]
          placement_id?: string | null
          product_id?: string | null
          project_id: string
          quantity: number
          rab_id: string
          service_rate_id?: string | null
          sort_order?: number
          subtotal_customer?: number | null
          subtotal_internal?: number | null
          unit: string
          unit_price_customer?: number
          unit_price_internal?: number
          updated_at?: string
          wall_paint_id?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          description?: string
          id?: string
          is_manual?: boolean
          item_type?: Database["public"]["Enums"]["rab_item_type"]
          placement_id?: string | null
          product_id?: string | null
          project_id?: string
          quantity?: number
          rab_id?: string
          service_rate_id?: string | null
          sort_order?: number
          subtotal_customer?: number | null
          subtotal_internal?: number | null
          unit?: string
          unit_price_customer?: number
          unit_price_internal?: number
          updated_at?: string
          wall_paint_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "rab_line_items_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "rab_line_items_placement_id_fkey"
            columns: ["placement_id"]
            isOneToOne: false
            referencedRelation: "furniture_placements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "rab_line_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "rab_line_items_rab_id_project_id_fkey"
            columns: ["rab_id", "project_id"]
            isOneToOne: false
            referencedRelation: "rabs"
            referencedColumns: ["id", "project_id"]
          },
          {
            foreignKeyName: "rab_line_items_service_rate_id_fkey"
            columns: ["service_rate_id"]
            isOneToOne: false
            referencedRelation: "service_rates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "rab_line_items_wall_paint_id_fkey"
            columns: ["wall_paint_id"]
            isOneToOne: false
            referencedRelation: "wall_paints"
            referencedColumns: ["id"]
          },
        ]
      }
      rab_snapshots: {
        Row: {
          created_at: string
          created_by: string | null
          data: Json
          id: string
          project_id: string
          version: number
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          data: Json
          id?: string
          project_id: string
          version: number
        }
        Update: {
          created_at?: string
          created_by?: string | null
          data?: Json
          id?: string
          project_id?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "rab_snapshots_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "rab_snapshots_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      rabs: {
        Row: {
          adjustment: number
          adjustment_note: string | null
          calculated_at: string | null
          calculated_by: string | null
          created_at: string
          grand_total_customer: number
          grand_total_internal: number
          id: string
          material_total_customer: number
          material_total_internal: number
          notes: string | null
          project_id: string
          service_total: number
          tax_amount: number
          tax_percent: number
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          adjustment?: number
          adjustment_note?: string | null
          calculated_at?: string | null
          calculated_by?: string | null
          created_at?: string
          grand_total_customer?: number
          grand_total_internal?: number
          id?: string
          material_total_customer?: number
          material_total_internal?: number
          notes?: string | null
          project_id: string
          service_total?: number
          tax_amount?: number
          tax_percent?: number
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          adjustment?: number
          adjustment_note?: string | null
          calculated_at?: string | null
          calculated_by?: string | null
          created_at?: string
          grand_total_customer?: number
          grand_total_internal?: number
          id?: string
          material_total_customer?: number
          material_total_internal?: number
          notes?: string | null
          project_id?: string
          service_total?: number
          tax_amount?: number
          tax_percent?: number
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "rabs_calculated_by_fkey"
            columns: ["calculated_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "rabs_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: true
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "rabs_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      reports: {
        Row: {
          generated_at: string
          generated_by: string | null
          id: string
          pdf_file_id: string | null
          pdf_url: string
          project_id: string
          snapshot_id: string
        }
        Insert: {
          generated_at?: string
          generated_by?: string | null
          id?: string
          pdf_file_id?: string | null
          pdf_url: string
          project_id: string
          snapshot_id: string
        }
        Update: {
          generated_at?: string
          generated_by?: string | null
          id?: string
          pdf_file_id?: string | null
          pdf_url?: string
          project_id?: string
          snapshot_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "reports_generated_by_fkey"
            columns: ["generated_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_snapshot_id_fkey"
            columns: ["snapshot_id"]
            isOneToOne: true
            referencedRelation: "rab_snapshots"
            referencedColumns: ["id"]
          },
        ]
      }
      room_measurements: {
        Row: {
          area: number | null
          area_type: Database["public"]["Enums"]["measurement_area_type"]
          created_at: string
          created_by: string | null
          height: number | null
          id: string
          label: string | null
          length: number
          project_id: string
          source: string
          unit: string
          updated_at: string
          wall_paint_id: string | null
          width: number
        }
        Insert: {
          area?: number | null
          area_type?: Database["public"]["Enums"]["measurement_area_type"]
          created_at?: string
          created_by?: string | null
          height?: number | null
          id?: string
          label?: string | null
          length: number
          project_id: string
          source?: string
          unit?: string
          updated_at?: string
          wall_paint_id?: string | null
          width: number
        }
        Update: {
          area?: number | null
          area_type?: Database["public"]["Enums"]["measurement_area_type"]
          created_at?: string
          created_by?: string | null
          height?: number | null
          id?: string
          label?: string | null
          length?: number
          project_id?: string
          source?: string
          unit?: string
          updated_at?: string
          wall_paint_id?: string | null
          width?: number
        }
        Relationships: [
          {
            foreignKeyName: "room_measurements_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "room_measurements_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "room_measurements_wall_paint_id_project_id_fkey"
            columns: ["wall_paint_id", "project_id"]
            isOneToOne: false
            referencedRelation: "wall_paints"
            referencedColumns: ["id", "project_id"]
          },
        ]
      }
      room_photos: {
        Row: {
          created_at: string
          height: number | null
          id: string
          metadata: Json
          original_file_id: string | null
          original_url: string
          processed_file_id: string | null
          processed_url: string | null
          project_id: string
          updated_at: string
          width: number | null
        }
        Insert: {
          created_at?: string
          height?: number | null
          id?: string
          metadata?: Json
          original_file_id?: string | null
          original_url: string
          processed_file_id?: string | null
          processed_url?: string | null
          project_id: string
          updated_at?: string
          width?: number | null
        }
        Update: {
          created_at?: string
          height?: number | null
          id?: string
          metadata?: Json
          original_file_id?: string | null
          original_url?: string
          processed_file_id?: string | null
          processed_url?: string | null
          project_id?: string
          updated_at?: string
          width?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "room_photos_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      service_rates: {
        Row: {
          active: boolean
          applies_to: Database["public"]["Enums"]["product_type"] | null
          calc_type: Database["public"]["Enums"]["service_calc_type"]
          code: string
          created_at: string
          id: string
          name: string
          rate: number
          updated_at: string
        }
        Insert: {
          active?: boolean
          applies_to?: Database["public"]["Enums"]["product_type"] | null
          calc_type: Database["public"]["Enums"]["service_calc_type"]
          code: string
          created_at?: string
          id?: string
          name: string
          rate: number
          updated_at?: string
        }
        Update: {
          active?: boolean
          applies_to?: Database["public"]["Enums"]["product_type"] | null
          calc_type?: Database["public"]["Enums"]["service_calc_type"]
          code?: string
          created_at?: string
          id?: string
          name?: string
          rate?: number
          updated_at?: string
        }
        Relationships: []
      }
      wall_paints: {
        Row: {
          color_hex: string | null
          color_name: string | null
          created_at: string
          id: string
          label: string | null
          mask_ref: Json
          photo_id: string
          preview_url: string | null
          product_id: string | null
          project_id: string
          updated_at: string
        }
        Insert: {
          color_hex?: string | null
          color_name?: string | null
          created_at?: string
          id?: string
          label?: string | null
          mask_ref?: Json
          photo_id: string
          preview_url?: string | null
          product_id?: string | null
          project_id: string
          updated_at?: string
        }
        Update: {
          color_hex?: string | null
          color_name?: string | null
          created_at?: string
          id?: string
          label?: string | null
          mask_ref?: Json
          photo_id?: string
          preview_url?: string | null
          product_id?: string | null
          project_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "wall_paints_photo_id_project_id_fkey"
            columns: ["photo_id", "project_id"]
            isOneToOne: false
            referencedRelation: "room_photos"
            referencedColumns: ["id", "project_id"]
          },
          {
            foreignKeyName: "wall_paints_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wall_paints_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      calculate_rab: {
        Args: { p_project_id: string }
        Returns: {
          adjustment: number
          adjustment_note: string | null
          calculated_at: string | null
          calculated_by: string | null
          created_at: string
          grand_total_customer: number
          grand_total_internal: number
          id: string
          material_total_customer: number
          material_total_internal: number
          notes: string | null
          project_id: string
          service_total: number
          tax_amount: number
          tax_percent: number
          updated_at: string
          updated_by: string | null
        }
        SetofOptions: {
          from: "*"
          to: "rabs"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      can_access_conversation: {
        Args: { p_conversation_id: string }
        Returns: boolean
      }
      can_edit_rab: { Args: { p_project_id: string }; Returns: boolean }
      can_read_project: { Args: { p_project_id: string }; Returns: boolean }
      change_project_status: {
        Args: {
          p_note?: string
          p_project_id: string
          p_to_status: Database["public"]["Enums"]["project_status"]
        }
        Returns: {
          assigned_admin_id: string | null
          code: string
          created_at: string
          customer_id: string
          final_snapshot_id: string | null
          id: string
          notes: string | null
          room_type: string | null
          status: Database["public"]["Enums"]["project_status"]
          submitted_at: string | null
          title: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "projects"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      customer_can_edit_project: {
        Args: { p_project_id: string }
        Returns: boolean
      }
      is_staff: { Args: never; Returns: boolean }
      is_super_admin: { Args: never; Returns: boolean }
      my_role: {
        Args: never
        Returns: Database["public"]["Enums"]["user_role"]
      }
      set_user_role: {
        Args: {
          p_role: Database["public"]["Enums"]["user_role"]
          p_user_id: string
        }
        Returns: {
          created_at: string
          email: string | null
          full_name: string | null
          id: string
          phone: string | null
          role: Database["public"]["Enums"]["user_role"]
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "profiles"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      staff_can_edit_project: {
        Args: { p_project_id: string }
        Returns: boolean
      }
    }
    Enums: {
      approval_decision: "approved" | "correction" | "rejected"
      conversation_status: "open" | "closed"
      measurement_area_type: "wall" | "floor" | "ceiling" | "other"
      product_type: "paint" | "furniture" | "material" | "other"
      project_status:
        | "draft"
        | "ready_to_submit"
        | "sent_to_admin"
        | "admin_processing"
        | "rab_draft"
        | "pending_approval"
        | "approved"
        | "correction"
        | "rejected"
        | "confirmed"
        | "report_generated"
        | "completed"
      rab_item_type: "material" | "furniture" | "service" | "other"
      service_calc_type: "per_m2" | "flat"
      user_role: "customer" | "admin" | "super_admin"
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
      approval_decision: ["approved", "correction", "rejected"],
      conversation_status: ["open", "closed"],
      measurement_area_type: ["wall", "floor", "ceiling", "other"],
      product_type: ["paint", "furniture", "material", "other"],
      project_status: [
        "draft",
        "ready_to_submit",
        "sent_to_admin",
        "admin_processing",
        "rab_draft",
        "pending_approval",
        "approved",
        "correction",
        "rejected",
        "confirmed",
        "report_generated",
        "completed",
      ],
      rab_item_type: ["material", "furniture", "service", "other"],
      service_calc_type: ["per_m2", "flat"],
      user_role: ["customer", "admin", "super_admin"],
    },
  },
} as const
