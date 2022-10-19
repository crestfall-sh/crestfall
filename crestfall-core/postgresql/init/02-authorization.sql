
-- https://www.postgresql.org/docs/14/functions-json.html
-- https://www.postgresql.org/docs/14/functions-aggregate.html
-- https://www.postgresql.org/docs/14/plpgsql-errors-and-messages.html

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE public.users (
  "id" uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  "email" text NOT NULL
);

CREATE TABLE public.roles (
  "id" uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  "name" text NOT NULL
);

CREATE TABLE public.permissions (
  "id" uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  "role_id" uuid REFERENCES public.roles NOT NULL,
  "resource" text NOT NULL, -- crestfall:authorization
  "actions" text[] NOT NULL -- read, write
);

CREATE TABLE public.assignments (
  "id" uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  "user_id" uuid REFERENCES public.users NOT NULL,
  "role_id" uuid REFERENCES public.roles NOT NULL,
  "assigned_by_user_id" uuid REFERENCES public.users DEFAULT NULL,
  "assigned_at" timestamptz DEFAULT now()
);

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;

-- public.is_authorized(user_id, resource, action) FUNCTION
CREATE OR REPLACE FUNCTION public.is_authorized (
  param_user_id uuid,
  param_resource text,
  param_action text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result boolean;
BEGIN
  SELECT 1 INTO result FROM public.assignments
  WHERE public.assignments.user_id = param_user_id
  AND EXISTS (
      SELECT 1 FROM public.permissions
      WHERE public.permissions.role_id = public.assignments.role_id
      AND param_resource = public.permissions.resource
      AND param_action = ANY(public.permissions.actions)
  );
  result = COALESCE(result, false);
  return result;
END;
$$;

-- auth.users AFTER INSERT FUNCTION
CREATE OR REPLACE FUNCTION auth_users_after_insert_function ()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
begin
  INSERT INTO public.profiles ("id", "email")
  VALUES (new.id, new.email);
  return new;
end;
$$;

-- auth.users AFTER INSERT TRIGGER
CREATE OR REPLACE TRIGGER auth_users_after_insert_trigger
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE PROCEDURE auth_users_after_insert_function();

-- INSERT auth.users INTO public.profiles
INSERT INTO public.profiles
SELECT "id", "email" FROM auth.users;

-- POLICY for public.profiles SELECT
DROP POLICY IF EXISTS profiles_select;
CREATE POLICY profiles_select ON public.profiles AS PERMISSIVE
FOR SELECT TO authenticated USING (
  profiles.id = auth.uid()
  OR is_authorized(auth.uid(), 'crestfall:authorization', 'read') = true
);

-- POLICY for public.roles SELECT
DROP POLICY IF EXISTS roles_select;
CREATE POLICY roles_select ON public.roles AS PERMISSIVE
FOR SELECT TO authenticated USING (
  EXISTS (
    SELECT 1 FROM assignments
    WHERE assignments.role_id = roles.id
    AND assignments.user_id = auth.uid()
  )
  OR is_authorized(auth.uid(), 'crestfall:authorization', 'read') = true
);

-- POLICY for public.permissions SELECT
DROP POLICY IF EXISTS permissions_select;
CREATE POLICY permissions_select ON public.permissions AS PERMISSIVE
FOR SELECT TO authenticated USING (
  EXISTS (
    SELECT 1 FROM roles
    WHERE roles.id = permissions.role_id
    AND EXISTS (
      SELECT 1 FROM assignments
      WHERE assignments.role_id = roles.id
      AND assignments.user_id = auth.uid()
    )
  )
  OR is_authorized(auth.uid(), 'crestfall:authorization', 'read') = true
);

-- POLICY for public.assignments SELECT
DROP POLICY IF EXISTS assignments_select;
CREATE POLICY assignments_select ON public.assignments AS PERMISSIVE
FOR SELECT TO authenticated USING (
  assignments.user_id = auth.uid()
  OR is_authorized(auth.uid(), 'crestfall:authorization', 'read') = true
);

-- POLICY for public.assignments INSERT
DROP POLICY IF EXISTS assignments_insert;
CREATE POLICY assignments_insert ON public.assignments AS PERMISSIVE
FOR INSERT TO authenticated WITH CHECK (
  is_authorized(auth.uid(), 'crestfall:authorization', 'write') = true
);

-- POLICY for public.assignments DELETE
DROP POLICY IF EXISTS assignments_delete;
CREATE POLICY assignments_delete ON public.assignments AS PERMISSIVE
FOR DELETE TO authenticated USING (
  is_authorized(auth.uid(), 'crestfall:authorization', 'write') = true
);


INSERT INTO public.users ("id", "email")
VALUES
  ('00000000-0000-0000-0000-000000000000', 'alice@example.com'),
  ('00000000-0000-0000-0000-000000000001', 'bob@example.com');

INSERT INTO public.roles ("name")
VALUES ('administrator'), ('moderator');

INSERT INTO public.permissions ("role_id", "resource", "actions")
VALUES (
  (SELECT "id" FROM public.roles WHERE "name" = 'administrator'),
  'crestfall:authentication',
  ARRAY['read', 'write']::text[]
);

INSERT INTO public.assignments ("user_id", "role_id")
VALUES (
  (SELECT "id" FROM public.users WHERE "email" = 'alice@example.com'),
  (SELECT "id" FROM public.roles WHERE "name" = 'administrator')
);
INSERT INTO public.assignments ("user_id", "role_id")
VALUES (
  (SELECT "id" FROM public.users WHERE "email" = 'alice@example.com'),
  (SELECT "id" FROM public.roles WHERE "name" = 'moderator')
);

SELECT * FROM public.users;

SELECT
  "email",
  is_authorized("id", 'crestfall:profiles', 'read') as profiles_read
  is_authorized("id", 'crestfall:authentication', 'read') as authn_read
  is_authorized("id", 'crestfall:authorization', 'read') as authz_read
FROM public.users;