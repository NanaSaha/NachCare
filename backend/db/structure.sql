SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: vector; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;


--
-- Name: EXTENSION vector; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION vector IS 'vector data type and ivfflat and hnsw access methods';


--
-- Name: audit_events_block_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.audit_events_block_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'audit_events is append-only: % is not permitted', TG_OP;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: activation_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activation_codes (
    id bigint NOT NULL,
    episode_ref bigint NOT NULL,
    code_digest character varying NOT NULL,
    role character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    used_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT activation_codes_role_check CHECK (((role)::text = ANY ((ARRAY['primary'::character varying, 'secondary'::character varying])::text[])))
);


--
-- Name: activation_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.activation_codes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: activation_codes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.activation_codes_id_seq OWNED BY public.activation_codes.id;


--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: ai_calls; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_calls (
    id bigint NOT NULL,
    task character varying NOT NULL,
    provider character varying NOT NULL,
    model character varying,
    status character varying DEFAULT 'success'::character varying NOT NULL,
    prompt_sha256 character varying NOT NULL,
    response_sha256 character varying,
    latency_ms integer,
    tokens_prompt integer,
    tokens_completion integer,
    guardrail_verdicts jsonb DEFAULT '{}'::jsonb NOT NULL,
    content text,
    caregiver_ref uuid,
    episode_ref bigint,
    conversation_ref bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT ai_calls_status_check CHECK (((status)::text = ANY ((ARRAY['success'::character varying, 'degraded'::character varying, 'failed'::character varying])::text[])))
);


--
-- Name: ai_calls_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_calls_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_calls_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_calls_id_seq OWNED BY public.ai_calls.id;


--
-- Name: analytics_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_events (
    id bigint NOT NULL,
    episode_pseudonym_ref character varying NOT NULL,
    name character varying NOT NULL,
    properties jsonb DEFAULT '{}'::jsonb NOT NULL,
    occurred_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: analytics_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.analytics_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: analytics_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.analytics_events_id_seq OWNED BY public.analytics_events.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: assistant_conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.assistant_conversations (
    id bigint NOT NULL,
    episode_ref bigint NOT NULL,
    caregiver_ref uuid NOT NULL,
    language character varying DEFAULT 'en'::character varying NOT NULL,
    started_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: assistant_conversations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.assistant_conversations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: assistant_conversations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.assistant_conversations_id_seq OWNED BY public.assistant_conversations.id;


--
-- Name: assistant_turns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.assistant_turns (
    id bigint NOT NULL,
    conversation_ref bigint NOT NULL,
    role character varying NOT NULL,
    content text,
    retrieval_refs jsonb DEFAULT '[]'::jsonb NOT NULL,
    guardrail_verdicts jsonb DEFAULT '{}'::jsonb NOT NULL,
    routed boolean DEFAULT false NOT NULL,
    emergency_detected boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT assistant_turns_role_check CHECK (((role)::text = ANY ((ARRAY['caregiver'::character varying, 'assistant'::character varying])::text[])))
);


--
-- Name: assistant_turns_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.assistant_turns_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: assistant_turns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.assistant_turns_id_seq OWNED BY public.assistant_turns.id;


--
-- Name: audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_events (
    id bigint NOT NULL,
    actor_type character varying NOT NULL,
    actor_ref character varying,
    action character varying NOT NULL,
    entity_type character varying NOT NULL,
    entity_ref character varying NOT NULL,
    payload_sha256 character varying NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT audit_events_actor_type_check CHECK (((actor_type)::text = ANY ((ARRAY['user'::character varying, 'caregiver'::character varying, 'system'::character varying, 'ai'::character varying])::text[])))
);


--
-- Name: audit_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audit_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audit_events_id_seq OWNED BY public.audit_events.id;


--
-- Name: cadence_proposals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cadence_proposals (
    id bigint NOT NULL,
    episode_ref bigint NOT NULL,
    direction character varying NOT NULL,
    proposed_cadence jsonb DEFAULT '{}'::jsonb NOT NULL,
    rationale text,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    decided_by bigint,
    decided_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT cadence_proposals_direction_check CHECK (((direction)::text = ANY ((ARRAY['taper'::character varying, 'densify'::character varying])::text[]))),
    CONSTRAINT cadence_proposals_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'approved'::character varying, 'dismissed'::character varying])::text[])))
);


--
-- Name: cadence_proposals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cadence_proposals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cadence_proposals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cadence_proposals_id_seq OWNED BY public.cadence_proposals.id;


--
-- Name: care_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.care_plans (
    id bigint NOT NULL,
    episode_ref bigint NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    active boolean DEFAULT false NOT NULL,
    thresholds jsonb DEFAULT '{}'::jsonb NOT NULL,
    diet_rules text,
    cadence jsonb DEFAULT '{}'::jsonb NOT NULL,
    approved_by bigint,
    approved_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    care_instructions text
);


--
-- Name: care_plans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.care_plans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: care_plans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.care_plans_id_seq OWNED BY public.care_plans.id;


--
-- Name: caregivers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.caregivers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    episode_ref bigint NOT NULL,
    display_name character varying NOT NULL,
    relationship character varying NOT NULL,
    language character varying DEFAULT 'en'::character varying NOT NULL,
    notification_time time without time zone,
    contact text,
    device_token_digest character varying,
    pin_digest character varying,
    push_subscription jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: check_in_photos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.check_in_photos (
    id bigint NOT NULL,
    check_in_ref bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: check_in_photos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.check_in_photos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: check_in_photos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.check_in_photos_id_seq OWNED BY public.check_in_photos.id;


--
-- Name: check_ins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.check_ins (
    id bigint NOT NULL,
    client_uuid uuid NOT NULL,
    episode_ref bigint NOT NULL,
    caregiver_ref uuid NOT NULL,
    submitted_at timestamp(6) without time zone NOT NULL,
    effective_date date NOT NULL,
    weight_kg numeric(5,2),
    weight_source character varying DEFAULT 'manual'::character varying NOT NULL,
    med_status jsonb DEFAULT '{}'::jsonb NOT NULL,
    symptoms jsonb DEFAULT '{}'::jsonb NOT NULL,
    note text,
    sync_state character varying DEFAULT 'synced'::character varying NOT NULL,
    superseded_by bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT check_ins_sync_state_check CHECK (((sync_state)::text = ANY ((ARRAY['synced'::character varying, 'pending'::character varying, 'conflict'::character varying])::text[]))),
    CONSTRAINT check_ins_weight_source_check CHECK (((weight_source)::text = 'manual'::text))
);


--
-- Name: check_ins_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.check_ins_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: check_ins_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.check_ins_id_seq OWNED BY public.check_ins.id;


--
-- Name: consents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.consents (
    id bigint NOT NULL,
    caregiver_ref uuid NOT NULL,
    kind character varying NOT NULL,
    version integer NOT NULL,
    granted boolean NOT NULL,
    "timestamp" timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT consents_kind_check CHECK (((kind)::text = ANY ((ARRAY['a'::character varying, 'b'::character varying, 'c'::character varying, 'd'::character varying])::text[])))
);


--
-- Name: consents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.consents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: consents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.consents_id_seq OWNED BY public.consents.id;


--
-- Name: content_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_items (
    id bigint NOT NULL,
    kind character varying NOT NULL,
    week_no integer NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    language_variants jsonb DEFAULT '{}'::jsonb NOT NULL,
    approvals jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT content_items_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'in_review'::character varying, 'approved'::character varying])::text[])))
);


--
-- Name: content_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_items_id_seq OWNED BY public.content_items.id;


--
-- Name: drugs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.drugs (
    id bigint NOT NULL,
    name character varying NOT NULL,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: drugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.drugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: drugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.drugs_id_seq OWNED BY public.drugs.id;


--
-- Name: episodes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.episodes (
    id bigint NOT NULL,
    patient_ref uuid NOT NULL,
    start_date date NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    milestones jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT episodes_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'graduated'::character varying, 'withdrawn'::character varying, 'deceased'::character varying])::text[])))
);


--
-- Name: episodes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.episodes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: episodes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.episodes_id_seq OWNED BY public.episodes.id;


--
-- Name: evaluations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.evaluations (
    id bigint NOT NULL,
    check_in_ref bigint,
    episode_ref bigint NOT NULL,
    ruleset_version character varying NOT NULL,
    inputs_sha256 character varying NOT NULL,
    severity character varying NOT NULL,
    fired_rules jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT evaluations_severity_check CHECK (((severity)::text = ANY ((ARRAY['green'::character varying, 'yellow'::character varying, 'red'::character varying])::text[])))
);


--
-- Name: evaluations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.evaluations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: evaluations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.evaluations_id_seq OWNED BY public.evaluations.id;


--
-- Name: flags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flags (
    id bigint NOT NULL,
    episode_ref bigint NOT NULL,
    evaluation_refs jsonb DEFAULT '[]'::jsonb NOT NULL,
    severity character varying NOT NULL,
    subtype character varying NOT NULL,
    state character varying DEFAULT 'open'::character varying NOT NULL,
    sla_deadline_at timestamp(6) without time zone,
    opened_at timestamp(6) without time zone NOT NULL,
    first_action_at timestamp(6) without time zone,
    resolved_at timestamp(6) without time zone,
    outcome character varying,
    breach boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    watch_expires_at timestamp(6) without time zone,
    ai_watch_meta jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT flags_severity_check CHECK (((severity)::text = ANY ((ARRAY['green'::character varying, 'yellow'::character varying, 'red'::character varying])::text[]))),
    CONSTRAINT flags_state_check CHECK (((state)::text = ANY ((ARRAY['open'::character varying, 'in_progress'::character varying, 'resolved'::character varying])::text[]))),
    CONSTRAINT flags_subtype_check CHECK (((subtype)::text = ANY ((ARRAY['clinical'::character varying, 'adherence'::character varying, 'manual'::character varying, 'ai_watch'::character varying])::text[])))
);


--
-- Name: flags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flags_id_seq OWNED BY public.flags.id;


--
-- Name: interventions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.interventions (
    id bigint NOT NULL,
    flag_ref bigint NOT NULL,
    actor_ref bigint NOT NULL,
    outcome character varying,
    note_ai text,
    note_final text,
    ai_accept_ratio numeric(4,3),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: interventions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.interventions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: interventions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.interventions_id_seq OWNED BY public.interventions.id;


--
-- Name: knowledge_chunks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.knowledge_chunks (
    id bigint NOT NULL,
    doc_ref bigint NOT NULL,
    chunk text NOT NULL,
    embedding public.vector(1024),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: knowledge_chunks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.knowledge_chunks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: knowledge_chunks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.knowledge_chunks_id_seq OWNED BY public.knowledge_chunks.id;


--
-- Name: knowledge_docs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.knowledge_docs (
    id bigint NOT NULL,
    title character varying NOT NULL,
    language character varying NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    body text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    approvals jsonb DEFAULT '[]'::jsonb NOT NULL,
    CONSTRAINT knowledge_docs_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'in_review'::character varying, 'approved'::character varying])::text[])))
);


--
-- Name: knowledge_docs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.knowledge_docs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: knowledge_docs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.knowledge_docs_id_seq OWNED BY public.knowledge_docs.id;


--
-- Name: medication_doses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.medication_doses (
    id bigint NOT NULL,
    medication_ref bigint NOT NULL,
    caregiver_ref uuid NOT NULL,
    scheduled_date date NOT NULL,
    scheduled_time time without time zone NOT NULL,
    taken_at timestamp(6) without time zone,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT medication_doses_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'taken'::character varying, 'missed'::character varying])::text[])))
);


--
-- Name: medication_doses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.medication_doses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: medication_doses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.medication_doses_id_seq OWNED BY public.medication_doses.id;


--
-- Name: medications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.medications (
    id bigint NOT NULL,
    care_plan_ref bigint NOT NULL,
    name character varying NOT NULL,
    drug_ref bigint,
    critical boolean DEFAULT false NOT NULL,
    schedule jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: medications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.medications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: medications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.medications_id_seq OWNED BY public.medications.id;


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id bigint NOT NULL,
    episode_ref bigint NOT NULL,
    sender character varying NOT NULL,
    template_key character varying,
    body_source text NOT NULL,
    body_translated text,
    language character varying DEFAULT 'en'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT messages_sender_check CHECK (((sender)::text = ANY ((ARRAY['nurse'::character varying, 'caregiver'::character varying, 'system'::character varying, 'ai'::character varying])::text[])))
);


--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.messages_id_seq OWNED BY public.messages.id;


--
-- Name: notification_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_attempts (
    id bigint NOT NULL,
    kind character varying NOT NULL,
    channel character varying NOT NULL,
    state character varying DEFAULT 'sent'::character varying NOT NULL,
    caregiver_ref uuid NOT NULL,
    flag_ref bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT notification_attempts_channel_check CHECK (((channel)::text = ANY ((ARRAY['webpush'::character varying, 'sms'::character varying, 'email'::character varying])::text[]))),
    CONSTRAINT notification_attempts_state_check CHECK (((state)::text = ANY ((ARRAY['sent'::character varying, 'confirmed'::character varying, 'failed'::character varying])::text[])))
);


--
-- Name: notification_attempts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notification_attempts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notification_attempts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notification_attempts_id_seq OWNED BY public.notification_attempts.id;


--
-- Name: patients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.patients (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pseudonym_code character varying NOT NULL,
    initials character varying NOT NULL,
    birth_year integer NOT NULL,
    nyha_class character varying NOT NULL,
    site_ref bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT patients_nyha_class_check CHECK (((nyha_class)::text = ANY ((ARRAY['I'::character varying, 'II'::character varying, 'III'::character varying, 'IV'::character varying])::text[])))
);


--
-- Name: risk_model_promotions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.risk_model_promotions (
    id bigint NOT NULL,
    site_ref bigint NOT NULL,
    decided_by bigint NOT NULL,
    version integer NOT NULL,
    gate_results jsonb DEFAULT '{}'::jsonb NOT NULL,
    gates_met boolean DEFAULT false NOT NULL,
    override boolean DEFAULT false NOT NULL,
    promoted boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: risk_model_promotions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.risk_model_promotions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: risk_model_promotions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.risk_model_promotions_id_seq OWNED BY public.risk_model_promotions.id;


--
-- Name: risk_scores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.risk_scores (
    id bigint NOT NULL,
    episode_ref bigint NOT NULL,
    check_in_ref bigint NOT NULL,
    score numeric(5,4) NOT NULL,
    components jsonb DEFAULT '{}'::jsonb NOT NULL,
    rules_severity character varying NOT NULL,
    alert_eligible boolean DEFAULT false NOT NULL,
    outcome character varying,
    outcome_evaluated_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT risk_scores_rules_severity_check CHECK (((rules_severity)::text = ANY ((ARRAY['green'::character varying, 'yellow'::character varying, 'red'::character varying])::text[])))
);


--
-- Name: risk_scores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.risk_scores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: risk_scores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.risk_scores_id_seq OWNED BY public.risk_scores.id;


--
-- Name: rulesets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rulesets (
    id bigint NOT NULL,
    version character varying NOT NULL,
    body jsonb NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    approved_by bigint,
    approved_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT rulesets_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'shadow'::character varying, 'active'::character varying, 'retired'::character varying])::text[])))
);


--
-- Name: rulesets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rulesets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rulesets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rulesets_id_seq OWNED BY public.rulesets.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sites (
    id bigint NOT NULL,
    name character varying NOT NULL,
    timezone character varying DEFAULT 'Europe/Berlin'::character varying NOT NULL,
    sla_red_minutes integer DEFAULT 30 NOT NULL,
    sla_yellow_minutes integer DEFAULT 240 NOT NULL,
    config jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: sites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sites_id_seq OWNED BY public.sites.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    site_ref bigint NOT NULL,
    role character varying NOT NULL,
    language character varying DEFAULT 'en'::character varying NOT NULL,
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp(6) without time zone,
    remember_created_at timestamp(6) without time zone,
    sign_in_count integer DEFAULT 0 NOT NULL,
    current_sign_in_at timestamp(6) without time zone,
    last_sign_in_at timestamp(6) without time zone,
    current_sign_in_ip character varying,
    last_sign_in_ip character varying,
    consumed_timestep integer,
    otp_required_for_login boolean DEFAULT false NOT NULL,
    jti character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    otp_secret character varying,
    CONSTRAINT users_role_check CHECK (((role)::text = ANY ((ARRAY['ward_nurse'::character varying, 'nurse'::character varying, 'physician'::character varying, 'site_admin'::character varying, 'sysadmin'::character varying, 'analyst'::character varying])::text[])))
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: activation_codes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activation_codes ALTER COLUMN id SET DEFAULT nextval('public.activation_codes_id_seq'::regclass);


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: ai_calls id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_calls ALTER COLUMN id SET DEFAULT nextval('public.ai_calls_id_seq'::regclass);


--
-- Name: analytics_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_events ALTER COLUMN id SET DEFAULT nextval('public.analytics_events_id_seq'::regclass);


--
-- Name: assistant_conversations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assistant_conversations ALTER COLUMN id SET DEFAULT nextval('public.assistant_conversations_id_seq'::regclass);


--
-- Name: assistant_turns id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assistant_turns ALTER COLUMN id SET DEFAULT nextval('public.assistant_turns_id_seq'::regclass);


--
-- Name: audit_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events ALTER COLUMN id SET DEFAULT nextval('public.audit_events_id_seq'::regclass);


--
-- Name: cadence_proposals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cadence_proposals ALTER COLUMN id SET DEFAULT nextval('public.cadence_proposals_id_seq'::regclass);


--
-- Name: care_plans id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.care_plans ALTER COLUMN id SET DEFAULT nextval('public.care_plans_id_seq'::regclass);


--
-- Name: check_in_photos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.check_in_photos ALTER COLUMN id SET DEFAULT nextval('public.check_in_photos_id_seq'::regclass);


--
-- Name: check_ins id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.check_ins ALTER COLUMN id SET DEFAULT nextval('public.check_ins_id_seq'::regclass);


--
-- Name: consents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consents ALTER COLUMN id SET DEFAULT nextval('public.consents_id_seq'::regclass);


--
-- Name: content_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_items ALTER COLUMN id SET DEFAULT nextval('public.content_items_id_seq'::regclass);


--
-- Name: drugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drugs ALTER COLUMN id SET DEFAULT nextval('public.drugs_id_seq'::regclass);


--
-- Name: episodes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.episodes ALTER COLUMN id SET DEFAULT nextval('public.episodes_id_seq'::regclass);


--
-- Name: evaluations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluations ALTER COLUMN id SET DEFAULT nextval('public.evaluations_id_seq'::regclass);


--
-- Name: flags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flags ALTER COLUMN id SET DEFAULT nextval('public.flags_id_seq'::regclass);


--
-- Name: interventions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interventions ALTER COLUMN id SET DEFAULT nextval('public.interventions_id_seq'::regclass);


--
-- Name: knowledge_chunks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.knowledge_chunks ALTER COLUMN id SET DEFAULT nextval('public.knowledge_chunks_id_seq'::regclass);


--
-- Name: knowledge_docs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.knowledge_docs ALTER COLUMN id SET DEFAULT nextval('public.knowledge_docs_id_seq'::regclass);


--
-- Name: medication_doses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medication_doses ALTER COLUMN id SET DEFAULT nextval('public.medication_doses_id_seq'::regclass);


--
-- Name: medications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medications ALTER COLUMN id SET DEFAULT nextval('public.medications_id_seq'::regclass);


--
-- Name: messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ALTER COLUMN id SET DEFAULT nextval('public.messages_id_seq'::regclass);


--
-- Name: notification_attempts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_attempts ALTER COLUMN id SET DEFAULT nextval('public.notification_attempts_id_seq'::regclass);


--
-- Name: risk_model_promotions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_model_promotions ALTER COLUMN id SET DEFAULT nextval('public.risk_model_promotions_id_seq'::regclass);


--
-- Name: risk_scores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_scores ALTER COLUMN id SET DEFAULT nextval('public.risk_scores_id_seq'::regclass);


--
-- Name: rulesets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rulesets ALTER COLUMN id SET DEFAULT nextval('public.rulesets_id_seq'::regclass);


--
-- Name: sites id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sites ALTER COLUMN id SET DEFAULT nextval('public.sites_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: activation_codes activation_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activation_codes
    ADD CONSTRAINT activation_codes_pkey PRIMARY KEY (id);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: ai_calls ai_calls_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_calls
    ADD CONSTRAINT ai_calls_pkey PRIMARY KEY (id);


--
-- Name: analytics_events analytics_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_events
    ADD CONSTRAINT analytics_events_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: assistant_conversations assistant_conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assistant_conversations
    ADD CONSTRAINT assistant_conversations_pkey PRIMARY KEY (id);


--
-- Name: assistant_turns assistant_turns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assistant_turns
    ADD CONSTRAINT assistant_turns_pkey PRIMARY KEY (id);


--
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


--
-- Name: cadence_proposals cadence_proposals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cadence_proposals
    ADD CONSTRAINT cadence_proposals_pkey PRIMARY KEY (id);


--
-- Name: care_plans care_plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.care_plans
    ADD CONSTRAINT care_plans_pkey PRIMARY KEY (id);


--
-- Name: caregivers caregivers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.caregivers
    ADD CONSTRAINT caregivers_pkey PRIMARY KEY (id);


--
-- Name: check_in_photos check_in_photos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.check_in_photos
    ADD CONSTRAINT check_in_photos_pkey PRIMARY KEY (id);


--
-- Name: check_ins check_ins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.check_ins
    ADD CONSTRAINT check_ins_pkey PRIMARY KEY (id);


--
-- Name: consents consents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consents
    ADD CONSTRAINT consents_pkey PRIMARY KEY (id);


--
-- Name: content_items content_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_items
    ADD CONSTRAINT content_items_pkey PRIMARY KEY (id);


--
-- Name: drugs drugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drugs
    ADD CONSTRAINT drugs_pkey PRIMARY KEY (id);


--
-- Name: episodes episodes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.episodes
    ADD CONSTRAINT episodes_pkey PRIMARY KEY (id);


--
-- Name: evaluations evaluations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluations
    ADD CONSTRAINT evaluations_pkey PRIMARY KEY (id);


--
-- Name: flags flags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flags
    ADD CONSTRAINT flags_pkey PRIMARY KEY (id);


--
-- Name: interventions interventions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interventions
    ADD CONSTRAINT interventions_pkey PRIMARY KEY (id);


--
-- Name: knowledge_chunks knowledge_chunks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.knowledge_chunks
    ADD CONSTRAINT knowledge_chunks_pkey PRIMARY KEY (id);


--
-- Name: knowledge_docs knowledge_docs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.knowledge_docs
    ADD CONSTRAINT knowledge_docs_pkey PRIMARY KEY (id);


--
-- Name: medication_doses medication_doses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medication_doses
    ADD CONSTRAINT medication_doses_pkey PRIMARY KEY (id);


--
-- Name: medications medications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medications
    ADD CONSTRAINT medications_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: notification_attempts notification_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_attempts
    ADD CONSTRAINT notification_attempts_pkey PRIMARY KEY (id);


--
-- Name: patients patients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_pkey PRIMARY KEY (id);


--
-- Name: risk_model_promotions risk_model_promotions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_model_promotions
    ADD CONSTRAINT risk_model_promotions_pkey PRIMARY KEY (id);


--
-- Name: risk_scores risk_scores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_scores
    ADD CONSTRAINT risk_scores_pkey PRIMARY KEY (id);


--
-- Name: rulesets rulesets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rulesets
    ADD CONSTRAINT rulesets_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sites sites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sites
    ADD CONSTRAINT sites_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_activation_codes_on_code_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_activation_codes_on_code_digest ON public.activation_codes USING btree (code_digest);


--
-- Name: index_activation_codes_on_episode_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activation_codes_on_episode_ref ON public.activation_codes USING btree (episode_ref);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_ai_calls_on_caregiver_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_calls_on_caregiver_ref ON public.ai_calls USING btree (caregiver_ref);


--
-- Name: index_ai_calls_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_calls_on_created_at ON public.ai_calls USING btree (created_at);


--
-- Name: index_ai_calls_on_episode_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_calls_on_episode_ref ON public.ai_calls USING btree (episode_ref);


--
-- Name: index_ai_calls_on_task; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_calls_on_task ON public.ai_calls USING btree (task);


--
-- Name: index_analytics_events_on_episode_pseudonym_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analytics_events_on_episode_pseudonym_ref ON public.analytics_events USING btree (episode_pseudonym_ref);


--
-- Name: index_analytics_events_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analytics_events_on_name ON public.analytics_events USING btree (name);


--
-- Name: index_analytics_events_on_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analytics_events_on_occurred_at ON public.analytics_events USING btree (occurred_at);


--
-- Name: index_assistant_conversations_on_caregiver_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assistant_conversations_on_caregiver_ref ON public.assistant_conversations USING btree (caregiver_ref);


--
-- Name: index_assistant_conversations_on_episode_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assistant_conversations_on_episode_ref ON public.assistant_conversations USING btree (episode_ref);


--
-- Name: index_assistant_turns_on_conversation_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assistant_turns_on_conversation_ref ON public.assistant_turns USING btree (conversation_ref);


--
-- Name: index_audit_events_on_actor_type_and_actor_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_actor_type_and_actor_ref ON public.audit_events USING btree (actor_type, actor_ref);


--
-- Name: index_audit_events_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_created_at ON public.audit_events USING btree (created_at);


--
-- Name: index_audit_events_on_entity_type_and_entity_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_entity_type_and_entity_ref ON public.audit_events USING btree (entity_type, entity_ref);


--
-- Name: index_cadence_proposals_on_episode_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cadence_proposals_on_episode_ref ON public.cadence_proposals USING btree (episode_ref);


--
-- Name: index_cadence_proposals_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cadence_proposals_on_status ON public.cadence_proposals USING btree (status);


--
-- Name: index_care_plans_on_episode_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_care_plans_on_episode_ref ON public.care_plans USING btree (episode_ref);


--
-- Name: index_care_plans_on_episode_ref_and_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_care_plans_on_episode_ref_and_version ON public.care_plans USING btree (episode_ref, version);


--
-- Name: index_care_plans_on_one_active_per_episode; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_care_plans_on_one_active_per_episode ON public.care_plans USING btree (episode_ref) WHERE (active = true);


--
-- Name: index_caregivers_on_device_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_caregivers_on_device_token_digest ON public.caregivers USING btree (device_token_digest);


--
-- Name: index_caregivers_on_episode_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_caregivers_on_episode_ref ON public.caregivers USING btree (episode_ref);


--
-- Name: index_check_in_photos_on_check_in_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_check_in_photos_on_check_in_ref ON public.check_in_photos USING btree (check_in_ref);


--
-- Name: index_check_ins_on_caregiver_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_check_ins_on_caregiver_ref ON public.check_ins USING btree (caregiver_ref);


--
-- Name: index_check_ins_on_client_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_check_ins_on_client_uuid ON public.check_ins USING btree (client_uuid);


--
-- Name: index_check_ins_on_effective_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_check_ins_on_effective_date ON public.check_ins USING btree (effective_date);


--
-- Name: index_check_ins_on_episode_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_check_ins_on_episode_ref ON public.check_ins USING btree (episode_ref);


--
-- Name: index_consents_on_caregiver_kind_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_consents_on_caregiver_kind_version ON public.consents USING btree (caregiver_ref, kind, version);


--
-- Name: index_consents_on_caregiver_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_consents_on_caregiver_ref ON public.consents USING btree (caregiver_ref);


--
-- Name: index_content_items_on_kind_and_week_no; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_content_items_on_kind_and_week_no ON public.content_items USING btree (kind, week_no);


--
-- Name: index_drugs_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_drugs_on_name ON public.drugs USING btree (name);


--
-- Name: index_episodes_on_patient_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_episodes_on_patient_ref ON public.episodes USING btree (patient_ref);


--
-- Name: index_episodes_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_episodes_on_status ON public.episodes USING btree (status);


--
-- Name: index_evaluations_on_check_in_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_evaluations_on_check_in_ref ON public.evaluations USING btree (check_in_ref);


--
-- Name: index_evaluations_on_episode_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_evaluations_on_episode_ref ON public.evaluations USING btree (episode_ref);


--
-- Name: index_evaluations_on_inputs_sha256; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_evaluations_on_inputs_sha256 ON public.evaluations USING btree (inputs_sha256);


--
-- Name: index_flags_on_episode_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flags_on_episode_ref ON public.flags USING btree (episode_ref);


--
-- Name: index_flags_on_sla_deadline_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flags_on_sla_deadline_at ON public.flags USING btree (sla_deadline_at);


--
-- Name: index_flags_on_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flags_on_state ON public.flags USING btree (state);


--
-- Name: index_flags_on_watch_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flags_on_watch_expires_at ON public.flags USING btree (watch_expires_at);


--
-- Name: index_interventions_on_actor_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_interventions_on_actor_ref ON public.interventions USING btree (actor_ref);


--
-- Name: index_interventions_on_flag_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_interventions_on_flag_ref ON public.interventions USING btree (flag_ref);


--
-- Name: index_knowledge_chunks_on_doc_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_knowledge_chunks_on_doc_ref ON public.knowledge_chunks USING btree (doc_ref);


--
-- Name: index_knowledge_docs_on_title_and_language_and_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_knowledge_docs_on_title_and_language_and_version ON public.knowledge_docs USING btree (title, language, version);


--
-- Name: index_medication_doses_on_caregiver_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_medication_doses_on_caregiver_ref ON public.medication_doses USING btree (caregiver_ref);


--
-- Name: index_medication_doses_on_med_date_time; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_medication_doses_on_med_date_time ON public.medication_doses USING btree (medication_ref, scheduled_date, scheduled_time);


--
-- Name: index_medication_doses_on_medication_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_medication_doses_on_medication_ref ON public.medication_doses USING btree (medication_ref);


--
-- Name: index_medications_on_care_plan_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_medications_on_care_plan_ref ON public.medications USING btree (care_plan_ref);


--
-- Name: index_medications_on_drug_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_medications_on_drug_ref ON public.medications USING btree (drug_ref);


--
-- Name: index_messages_on_episode_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_episode_ref ON public.messages USING btree (episode_ref);


--
-- Name: index_notification_attempts_on_caregiver_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_attempts_on_caregiver_ref ON public.notification_attempts USING btree (caregiver_ref);


--
-- Name: index_notification_attempts_on_flag_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_attempts_on_flag_ref ON public.notification_attempts USING btree (flag_ref);


--
-- Name: index_notification_attempts_on_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_attempts_on_state ON public.notification_attempts USING btree (state);


--
-- Name: index_patients_on_pseudonym_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_patients_on_pseudonym_code ON public.patients USING btree (pseudonym_code);


--
-- Name: index_patients_on_site_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_patients_on_site_ref ON public.patients USING btree (site_ref);


--
-- Name: index_risk_model_promotions_on_site_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_risk_model_promotions_on_site_ref ON public.risk_model_promotions USING btree (site_ref);


--
-- Name: index_risk_model_promotions_on_site_ref_and_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_risk_model_promotions_on_site_ref_and_version ON public.risk_model_promotions USING btree (site_ref, version);


--
-- Name: index_risk_scores_on_check_in_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_risk_scores_on_check_in_ref ON public.risk_scores USING btree (check_in_ref);


--
-- Name: index_risk_scores_on_episode_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_risk_scores_on_episode_ref ON public.risk_scores USING btree (episode_ref);


--
-- Name: index_risk_scores_on_outcome_evaluated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_risk_scores_on_outcome_evaluated_at ON public.risk_scores USING btree (outcome_evaluated_at);


--
-- Name: index_rulesets_on_one_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_rulesets_on_one_active ON public.rulesets USING btree (status) WHERE ((status)::text = 'active'::text);


--
-- Name: index_rulesets_on_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_rulesets_on_version ON public.rulesets USING btree (version);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_jti ON public.users USING btree (jti);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: index_users_on_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_role ON public.users USING btree (role);


--
-- Name: index_users_on_site_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_site_ref ON public.users USING btree (site_ref);


--
-- Name: audit_events audit_events_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_events_no_delete BEFORE DELETE ON public.audit_events FOR EACH ROW EXECUTE FUNCTION public.audit_events_block_mutation();


--
-- Name: audit_events audit_events_no_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_events_no_update BEFORE UPDATE ON public.audit_events FOR EACH ROW EXECUTE FUNCTION public.audit_events_block_mutation();


--
-- Name: check_in_photos fk_rails_0131da1afb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.check_in_photos
    ADD CONSTRAINT fk_rails_0131da1afb FOREIGN KEY (check_in_ref) REFERENCES public.check_ins(id);


--
-- Name: notification_attempts fk_rails_02469c74ee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_attempts
    ADD CONSTRAINT fk_rails_02469c74ee FOREIGN KEY (flag_ref) REFERENCES public.flags(id);


--
-- Name: medications fk_rails_03931ce87c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medications
    ADD CONSTRAINT fk_rails_03931ce87c FOREIGN KEY (drug_ref) REFERENCES public.drugs(id);


--
-- Name: notification_attempts fk_rails_07c89df079; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_attempts
    ADD CONSTRAINT fk_rails_07c89df079 FOREIGN KEY (caregiver_ref) REFERENCES public.caregivers(id);


--
-- Name: interventions fk_rails_0be6f9d2e4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interventions
    ADD CONSTRAINT fk_rails_0be6f9d2e4 FOREIGN KEY (actor_ref) REFERENCES public.users(id);


--
-- Name: caregivers fk_rails_1afde8b8dc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.caregivers
    ADD CONSTRAINT fk_rails_1afde8b8dc FOREIGN KEY (episode_ref) REFERENCES public.episodes(id);


--
-- Name: risk_model_promotions fk_rails_322a494348; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_model_promotions
    ADD CONSTRAINT fk_rails_322a494348 FOREIGN KEY (site_ref) REFERENCES public.sites(id);


--
-- Name: check_ins fk_rails_3cb0cd1306; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.check_ins
    ADD CONSTRAINT fk_rails_3cb0cd1306 FOREIGN KEY (caregiver_ref) REFERENCES public.caregivers(id);


--
-- Name: activation_codes fk_rails_3f5390c113; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activation_codes
    ADD CONSTRAINT fk_rails_3f5390c113 FOREIGN KEY (episode_ref) REFERENCES public.episodes(id);


--
-- Name: knowledge_chunks fk_rails_4bc8f4112b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.knowledge_chunks
    ADD CONSTRAINT fk_rails_4bc8f4112b FOREIGN KEY (doc_ref) REFERENCES public.knowledge_docs(id);


--
-- Name: risk_scores fk_rails_4d53b5637f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_scores
    ADD CONSTRAINT fk_rails_4d53b5637f FOREIGN KEY (check_in_ref) REFERENCES public.check_ins(id);


--
-- Name: assistant_turns fk_rails_4fbc3036f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assistant_turns
    ADD CONSTRAINT fk_rails_4fbc3036f0 FOREIGN KEY (conversation_ref) REFERENCES public.assistant_conversations(id);


--
-- Name: ai_calls fk_rails_5659a448e5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_calls
    ADD CONSTRAINT fk_rails_5659a448e5 FOREIGN KEY (conversation_ref) REFERENCES public.assistant_conversations(id);


--
-- Name: evaluations fk_rails_5d8be6f01e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluations
    ADD CONSTRAINT fk_rails_5d8be6f01e FOREIGN KEY (episode_ref) REFERENCES public.episodes(id);


--
-- Name: medication_doses fk_rails_7043f4761c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medication_doses
    ADD CONSTRAINT fk_rails_7043f4761c FOREIGN KEY (medication_ref) REFERENCES public.medications(id);


--
-- Name: flags fk_rails_7600f6cab5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flags
    ADD CONSTRAINT fk_rails_7600f6cab5 FOREIGN KEY (episode_ref) REFERENCES public.episodes(id);


--
-- Name: medication_doses fk_rails_7a5b5a46ff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medication_doses
    ADD CONSTRAINT fk_rails_7a5b5a46ff FOREIGN KEY (caregiver_ref) REFERENCES public.caregivers(id);


--
-- Name: assistant_conversations fk_rails_7afb478ca5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assistant_conversations
    ADD CONSTRAINT fk_rails_7afb478ca5 FOREIGN KEY (caregiver_ref) REFERENCES public.caregivers(id);


--
-- Name: assistant_conversations fk_rails_7bb20d257a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assistant_conversations
    ADD CONSTRAINT fk_rails_7bb20d257a FOREIGN KEY (episode_ref) REFERENCES public.episodes(id);


--
-- Name: ai_calls fk_rails_809cc0b607; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_calls
    ADD CONSTRAINT fk_rails_809cc0b607 FOREIGN KEY (episode_ref) REFERENCES public.episodes(id);


--
-- Name: check_ins fk_rails_88ad809771; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.check_ins
    ADD CONSTRAINT fk_rails_88ad809771 FOREIGN KEY (superseded_by) REFERENCES public.check_ins(id);


--
-- Name: consents fk_rails_97a7b9b3c3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consents
    ADD CONSTRAINT fk_rails_97a7b9b3c3 FOREIGN KEY (caregiver_ref) REFERENCES public.caregivers(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: cadence_proposals fk_rails_9d1d4d1ae5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cadence_proposals
    ADD CONSTRAINT fk_rails_9d1d4d1ae5 FOREIGN KEY (decided_by) REFERENCES public.users(id);


--
-- Name: patients fk_rails_a67ba42b4f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT fk_rails_a67ba42b4f FOREIGN KEY (site_ref) REFERENCES public.sites(id);


--
-- Name: episodes fk_rails_a6b2b4025d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.episodes
    ADD CONSTRAINT fk_rails_a6b2b4025d FOREIGN KEY (patient_ref) REFERENCES public.patients(id);


--
-- Name: ai_calls fk_rails_b0dc51f4a4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_calls
    ADD CONSTRAINT fk_rails_b0dc51f4a4 FOREIGN KEY (caregiver_ref) REFERENCES public.caregivers(id);


--
-- Name: medications fk_rails_bc5c54662d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medications
    ADD CONSTRAINT fk_rails_bc5c54662d FOREIGN KEY (care_plan_ref) REFERENCES public.care_plans(id);


--
-- Name: users fk_rails_bec3ea05a4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_bec3ea05a4 FOREIGN KEY (site_ref) REFERENCES public.sites(id);


--
-- Name: check_ins fk_rails_c02f5e5a10; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.check_ins
    ADD CONSTRAINT fk_rails_c02f5e5a10 FOREIGN KEY (episode_ref) REFERENCES public.episodes(id);


--
-- Name: risk_model_promotions fk_rails_c288b3ce35; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_model_promotions
    ADD CONSTRAINT fk_rails_c288b3ce35 FOREIGN KEY (decided_by) REFERENCES public.users(id);


--
-- Name: evaluations fk_rails_c2d36cbf4a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluations
    ADD CONSTRAINT fk_rails_c2d36cbf4a FOREIGN KEY (check_in_ref) REFERENCES public.check_ins(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: cadence_proposals fk_rails_c791e9474c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cadence_proposals
    ADD CONSTRAINT fk_rails_c791e9474c FOREIGN KEY (episode_ref) REFERENCES public.episodes(id);


--
-- Name: messages fk_rails_c8ed0b76a7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_c8ed0b76a7 FOREIGN KEY (episode_ref) REFERENCES public.episodes(id);


--
-- Name: interventions fk_rails_d01610c049; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interventions
    ADD CONSTRAINT fk_rails_d01610c049 FOREIGN KEY (flag_ref) REFERENCES public.flags(id);


--
-- Name: care_plans fk_rails_e82141488e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.care_plans
    ADD CONSTRAINT fk_rails_e82141488e FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: care_plans fk_rails_e917dbf2dd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.care_plans
    ADD CONSTRAINT fk_rails_e917dbf2dd FOREIGN KEY (episode_ref) REFERENCES public.episodes(id);


--
-- Name: risk_scores fk_rails_f1e92c4b67; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_scores
    ADD CONSTRAINT fk_rails_f1e92c4b67 FOREIGN KEY (episode_ref) REFERENCES public.episodes(id);


--
-- Name: rulesets fk_rails_f20ad15c99; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rulesets
    ADD CONSTRAINT fk_rails_f20ad15c99 FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260803190006'),
('20260803190005'),
('20260803190004'),
('20260803190003'),
('20260803190002'),
('20260803190001'),
('20260803180002'),
('20260803180001'),
('20260803170002'),
('20260803170001'),
('20260803100001'),
('20260803090001'),
('20260802160026'),
('20260802160025'),
('20260802160024'),
('20260802160023'),
('20260802160022'),
('20260802160021'),
('20260802160020'),
('20260802160019'),
('20260802160018'),
('20260802160017'),
('20260802160016'),
('20260802160015'),
('20260802160014'),
('20260802160013'),
('20260802160012'),
('20260802160011'),
('20260802160010'),
('20260802160009'),
('20260802160008'),
('20260802160007'),
('20260802160006'),
('20260802160005'),
('20260802160004'),
('20260802160003'),
('20260802160002'),
('20260802160001');

