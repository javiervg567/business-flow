-- ============================================================
-- Business Flow - Políticas de Row Level Security (RLS)
-- ============================================================
-- Activa la seguridad a nivel de fila en todas las tablas.
-- Cada SELECT/INSERT/UPDATE/DELETE pasa por las políticas
-- que definimos abajo. Sin política → acceso denegado.
-- ============================================================


-- ----------- 1. FUNCIONES AUXILIARES -------------------------
-- Estas funciones leen el perfil del usuario logueado para
-- usarlas en las políticas. Las marcamos como `stable` para
-- que Postgres las cachee dentro de la misma consulta (rendimiento).

-- Devuelve el business_id del usuario actual
create or replace function current_business_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select business_id from profiles where id = auth.uid()
$$;

-- Devuelve el rol del usuario actual ('admin', 'employee', 'client')
create or replace function current_role_name()
returns user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from profiles where id = auth.uid()
$$;

-- Devuelve true si el usuario es admin
create or replace function is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1 from profiles where id = auth.uid() and role = 'admin'
  )
$$;


-- ----------- 2. ACTIVAR RLS EN TODAS LAS TABLAS --------------
-- Sin esto, las políticas no hacen nada.
alter table businesses          enable row level security;
alter table profiles            enable row level security;
alter table services            enable row level security;
alter table employees_services  enable row level security;
alter table bookings            enable row level security;
alter table products            enable row level security;
alter table stock_movements     enable row level security;
alter table invoices            enable row level security;
alter table invoice_lines       enable row level security;


-- ============================================================
-- 3. POLÍTICAS POR TABLA
-- ============================================================
-- Sintaxis: create policy "nombre" on tabla
--           for {select|insert|update|delete|all}
--           to {anon|authenticated}
--           using (condición de lectura)
--           with check (condición al escribir)
-- ============================================================


-- ----------- BUSINESSES --------------------------------------
-- Cualquier usuario autenticado ve SU negocio.
create policy "Ver mi propio negocio"
  on businesses for select
  to authenticated
  using (id = current_business_id());

-- Solo admins pueden modificar su negocio.
create policy "Admin actualiza su negocio"
  on businesses for update
  to authenticated
  using (id = current_business_id() and is_admin())
  with check (id = current_business_id() and is_admin());


-- ----------- PROFILES ----------------------------------------
-- Cada usuario ve su propio perfil + admins ven todos los de su negocio.
create policy "Ver perfiles de mi negocio"
  on profiles for select
  to authenticated
  using (
    id = auth.uid()
    or business_id = current_business_id()
  );

-- Cada usuario puede actualizar su propio perfil.
create policy "Actualizar mi perfil"
  on profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Solo admins pueden insertar/borrar perfiles dentro de su negocio.
-- (Útil para crear empleados desde el panel admin)
create policy "Admin gestiona perfiles del negocio"
  on profiles for insert
  to authenticated
  with check (business_id = current_business_id() and is_admin());

create policy "Admin elimina perfiles del negocio"
  on profiles for delete
  to authenticated
  using (business_id = current_business_id() and is_admin());


-- ----------- SERVICES ----------------------------------------
-- Cualquier usuario del negocio puede VER los servicios.
create policy "Ver servicios de mi negocio"
  on services for select
  to authenticated
  using (business_id = current_business_id());

-- Solo admins crean/modifican/borran servicios.
create policy "Admin gestiona servicios"
  on services for all
  to authenticated
  using (business_id = current_business_id() and is_admin())
  with check (business_id = current_business_id() and is_admin());


-- ----------- EMPLOYEES_SERVICES ------------------------------
-- Tabla puente. Cualquier usuario del negocio puede leer.
create policy "Ver asignaciones empleados-servicios"
  on employees_services for select
  to authenticated
  using (
    exists(
      select 1 from profiles p
      where p.id = employees_services.employee_id
        and p.business_id = current_business_id()
    )
  );

create policy "Admin gestiona asignaciones"
  on employees_services for all
  to authenticated
  using (is_admin())
  with check (is_admin());


-- ----------- BOOKINGS (reservas) -----------------------------
-- Clientes ven SUS reservas.
-- Empleados ven las reservas que les han asignado + las de su negocio.
-- Admins ven todas las del negocio.
create policy "Ver reservas seg\u00fan rol"
  on bookings for select
  to authenticated
  using (
    business_id = current_business_id()
    and (
      is_admin()
      or current_role_name() = 'employee'
      or client_id = auth.uid()
    )
  );

-- Clientes pueden crear sus propias reservas.
create policy "Cliente crea sus reservas"
  on bookings for insert
  to authenticated
  with check (
    business_id = current_business_id()
    and client_id = auth.uid()
  );

-- Admins crean reservas para cualquier cliente del negocio.
create policy "Admin crea reservas"
  on bookings for insert
  to authenticated
  with check (
    business_id = current_business_id() and is_admin()
  );

-- Cliente puede actualizar/cancelar SUS reservas (con limitaciones lógicas
-- que aplicaremos a nivel de app: no cancelar tarde, etc.).
create policy "Cliente actualiza sus reservas"
  on bookings for update
  to authenticated
  using (client_id = auth.uid())
  with check (client_id = auth.uid());

-- Admin puede actualizar/borrar cualquier reserva del negocio.
create policy "Admin gestiona reservas"
  on bookings for all
  to authenticated
  using (business_id = current_business_id() and is_admin())
  with check (business_id = current_business_id() and is_admin());


-- ----------- PRODUCTS (inventario) ---------------------------
-- Solo personal del negocio (admin/employee) ve y gestiona inventario.
-- Los clientes NO acceden a esta tabla.
create policy "Personal ve inventario"
  on products for select
  to authenticated
  using (
    business_id = current_business_id()
    and current_role_name() in ('admin', 'employee')
  );

create policy "Admin gestiona inventario"
  on products for all
  to authenticated
  using (business_id = current_business_id() and is_admin())
  with check (business_id = current_business_id() and is_admin());


-- ----------- STOCK_MOVEMENTS (histórico stock) ---------------
create policy "Personal ve movimientos de stock"
  on stock_movements for select
  to authenticated
  using (
    exists(
      select 1 from products p
      where p.id = stock_movements.product_id
        and p.business_id = current_business_id()
    )
    and current_role_name() in ('admin', 'employee')
  );

create policy "Personal registra movimientos"
  on stock_movements for insert
  to authenticated
  with check (
    exists(
      select 1 from products p
      where p.id = stock_movements.product_id
        and p.business_id = current_business_id()
    )
    and current_role_name() in ('admin', 'employee')
  );


-- ----------- INVOICES (facturas) -----------------------------
-- Cliente ve SUS facturas. Admin ve todas las del negocio.
create policy "Ver facturas seg\u00fan rol"
  on invoices for select
  to authenticated
  using (
    business_id = current_business_id()
    and (is_admin() or client_id = auth.uid())
  );

-- Solo admins crean/modifican facturas.
create policy "Admin gestiona facturas"
  on invoices for all
  to authenticated
  using (business_id = current_business_id() and is_admin())
  with check (business_id = current_business_id() and is_admin());


-- ----------- INVOICE_LINES -----------------------------------
-- Las líneas heredan los permisos de su factura.
create policy "Ver lineas de mis facturas"
  on invoice_lines for select
  to authenticated
  using (
    exists(
      select 1 from invoices i
      where i.id = invoice_lines.invoice_id
        and i.business_id = current_business_id()
        and (is_admin() or i.client_id = auth.uid())
    )
  );

create policy "Admin gestiona lineas de factura"
  on invoice_lines for all
  to authenticated
  using (
    exists(
      select 1 from invoices i
      where i.id = invoice_lines.invoice_id
        and i.business_id = current_business_id()
        and is_admin()
    )
  )
  with check (
    exists(
      select 1 from invoices i
      where i.id = invoice_lines.invoice_id
        and i.business_id = current_business_id()
        and is_admin()
    )
  );