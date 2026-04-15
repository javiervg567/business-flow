-- ============================================================
-- Business Flow - Esquema inicial
-- Multi-tenant: cada fila pertenece a un business
-- ============================================================

-- ----------- 1. EXTENSIONES Y TIPOS ENUMERADOS ----------------

-- pgcrypto nos da gen_random_uuid() para generar IDs únicos.
create extension if not exists "pgcrypto";

-- Tipos enumerados: definen valores permitidos para ciertos campos.
-- Si intentas meter un valor distinto, la BBDD lo rechaza.
create type business_type as enum ('peluqueria', 'estetica', 'restaurante', 'clinica', 'otro');
create type user_role as enum ('admin', 'employee', 'client');
create type booking_status as enum ('pending', 'confirmed', 'completed', 'cancelled', 'waitlist');
create type stock_movement_type as enum ('in', 'out', 'adjustment');
create type invoice_status as enum ('pending', 'paid', 'cancelled');

-- ----------- 2. TABLA RAÍZ: BUSINESSES -----------------------

create table businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type business_type not null default 'otro',
  timezone text not null default 'Europe/Madrid',
  created_at timestamptz not null default now()
);

-- ----------- 3. PROFILES (extiende a auth.users) -------------

-- En Supabase, los usuarios viven en auth.users (gestionado por Supabase Auth).
-- Aquí extendemos esa tabla con datos del negocio.
-- El 'id' es el MISMO uuid que en auth.users (relación 1 a 1).
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  business_id uuid not null references businesses(id) on delete cascade,
  role user_role not null,
  full_name text not null,
  email text not null,
  phone text,
  created_at timestamptz not null default now()
);

create index idx_profiles_business on profiles(business_id);
create index idx_profiles_role on profiles(role);

-- ----------- 4. SERVICES -------------------------------------

create table services (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  name text not null,
  description text,
  duration_minutes int not null check (duration_minutes > 0),
  price numeric(10,2) not null check (price >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create index idx_services_business on services(business_id);

-- ----------- 5. EMPLOYEES_SERVICES (muchos-a-muchos) ---------

-- Tabla puente: qué empleados pueden hacer qué servicios.
create table employees_services (
  employee_id uuid not null references profiles(id) on delete cascade,
  service_id uuid not null references services(id) on delete cascade,
  primary key (employee_id, service_id)
);

-- ----------- 6. BOOKINGS (reservas) --------------------------

create table bookings (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  client_id uuid not null references profiles(id) on delete restrict,
  employee_id uuid references profiles(id) on delete set null,
  service_id uuid not null references services(id) on delete restrict,
  start_at timestamptz not null,
  end_at timestamptz not null,
  status booking_status not null default 'pending',
  notes text,
  created_at timestamptz not null default now(),
  check (end_at > start_at)
);

create index idx_bookings_business on bookings(business_id);
create index idx_bookings_client on bookings(client_id);
create index idx_bookings_employee on bookings(employee_id);
create index idx_bookings_start on bookings(start_at);

-- ----------- 7. PRODUCTS (inventario) ------------------------

create table products (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  sku text,
  name text not null,
  category text,
  stock int not null default 0 check (stock >= 0),
  min_stock int not null default 0 check (min_stock >= 0),
  price numeric(10,2) not null default 0 check (price >= 0),
  created_at timestamptz not null default now(),
  unique (business_id, sku)
);

create index idx_products_business on products(business_id);

-- ----------- 8. STOCK_MOVEMENTS (histórico) ------------------

create table stock_movements (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  type stock_movement_type not null,
  quantity int not null check (quantity > 0),
  reason text,
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index idx_stock_movements_product on stock_movements(product_id);

-- ----------- 9. INVOICES (facturas) --------------------------

create table invoices (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  client_id uuid not null references profiles(id) on delete restrict,
  booking_id uuid references bookings(id) on delete set null,
  number text not null,
  issued_at timestamptz not null default now(),
  subtotal numeric(10,2) not null default 0,
  tax_amount numeric(10,2) not null default 0,
  total numeric(10,2) not null default 0,
  status invoice_status not null default 'pending',
  pdf_url text,
  created_at timestamptz not null default now(),
  unique (business_id, number)
);

create index idx_invoices_business on invoices(business_id);
create index idx_invoices_client on invoices(client_id);

-- ----------- 10. INVOICE_LINES (líneas de factura) -----------

create table invoice_lines (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references invoices(id) on delete cascade,
  description text not null,
  quantity numeric(10,2) not null default 1 check (quantity > 0),
  unit_price numeric(10,2) not null default 0 check (unit_price >= 0),
  tax_rate numeric(5,2) not null default 21.00 check (tax_rate >= 0)
);

create index idx_invoice_lines_invoice on invoice_lines(invoice_id);