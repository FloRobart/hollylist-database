\restrict dbmate

-- Dumped from database version 18.6 (Debian 18.6-1.pgdg13+2)
-- Dumped by pg_dump version 18.6

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
-- Name: update_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: gifts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gifts (
    id integer NOT NULL,
    gift_name character varying(255) NOT NULL,
    gift_description text,
    gift_year integer,
    price numeric(12,2) DEFAULT 0 NOT NULL,
    link character varying(2048),
    people_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT check_gifts_price_not_negative CHECK ((price >= (0)::numeric))
);


--
-- Name: gifts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.gifts ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.gifts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: peoples; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.peoples (
    id integer NOT NULL,
    first_name character varying(255) NOT NULL,
    last_name character varying(255) DEFAULT NULL::character varying,
    date_of_birth date,
    user_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: peoples_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.peoples ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.peoples_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: gifts gifts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gifts
    ADD CONSTRAINT gifts_pkey PRIMARY KEY (id);


--
-- Name: peoples peoples_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.peoples
    ADD CONSTRAINT peoples_id_user_id_key UNIQUE (id, user_id);


--
-- Name: peoples peoples_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.peoples
    ADD CONSTRAINT peoples_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: gifts_user_id_people_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX gifts_user_id_people_id_idx ON public.gifts USING btree (user_id, people_id);


--
-- Name: peoples_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX peoples_user_id_idx ON public.peoples USING btree (user_id);


--
-- Name: gifts update_gifts_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_gifts_updated_at BEFORE UPDATE ON public.gifts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: peoples update_peoples_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_peoples_updated_at BEFORE UPDATE ON public.peoples FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: gifts gifts_people_id_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gifts
    ADD CONSTRAINT gifts_people_id_user_id_fkey FOREIGN KEY (people_id, user_id) REFERENCES public.peoples(id, user_id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict dbmate


--
-- Dbmate schema migrations
--

INSERT INTO public.schema_migrations (version) VALUES
    ('20261108120000');
