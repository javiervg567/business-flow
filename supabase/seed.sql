-- ============================================================
-- Business Flow - Datos de ejemplo (seed)
-- Negocio ficticio: "Peluquería Bella"
-- ============================================================


-- ----------- 1. NEGOCIO ---------------------------------------
-- Generamos un UUID fijo para el negocio para poder referenciarlo
-- desde el resto del script. En producción se generaría con gen_random_uuid().
insert into businesses (id, name, type, timezone)
values ('11111111-1111-1111-1111-111111111111',
        'Peluquería Bella', 'peluqueria', 'Europe/Madrid');


-- ----------- 2. USUARIOS "FANTASMA" EN auth.users -------------
-- Estos usuarios existen en el sistema de auth pero no pueden
-- hacer login (no tienen contraseña usable). Solo sirven para que
-- los profiles tengan a qué apuntar y respetar la FK.
--
-- Los UUIDs los inventamos para tener IDs predecibles en los seeds.

insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data,
                        created_at, updated_at)
values
  -- Empleados (peluqueros)
  ('22222222-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'lucia@bella.test', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),

  ('22222222-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'marcos@bella.test', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),

  ('22222222-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'sofia@bella.test', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),

  -- Cliente extra admin (segundo administrador)
  ('22222222-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'jefe@bella.test', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),

  -- Otros clientes (ana ya existe como real)
  ('33333333-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'carlos@cliente.test', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),

  ('33333333-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'maria@cliente.test', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),

  ('33333333-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'pedro@cliente.test', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),

  ('33333333-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'laura@cliente.test', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now());


-- ----------- 3. PROFILES --------------------------------------
-- Conecta cada usuario con el negocio y le asigna su rol.

insert into profiles (id, business_id, role, full_name, email, phone)
values
  -- Admins
  ('1d646969-cb7b-4e09-8309-3f73eb653451', '11111111-1111-1111-1111-111111111111',
   'admin', 'Javier Valle', 'admin@bella.test', '+34 600 100 101'),

  ('22222222-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111',
   'admin', 'Carmen López', 'jefe@bella.test', '+34 600 100 102'),

  -- Empleados
  ('22222222-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'employee', 'Lucía Ramírez', 'lucia@bella.test', '+34 600 200 201'),

  ('22222222-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   'employee', 'Marcos Díaz', 'marcos@bella.test', '+34 600 200 202'),

  ('22222222-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111',
   'employee', 'Sofía Pérez', 'sofia@bella.test', '+34 600 200 203'),

  -- Clientes
  ('c1837a31-cd30-44f9-8619-2d524ba677fe', '11111111-1111-1111-1111-111111111111',
   'client', 'Ana García', 'ana@cliente.test', '+34 600 300 301'),

  ('33333333-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'client', 'Carlos Moreno', 'carlos@cliente.test', '+34 600 300 302'),

  ('33333333-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   'client', 'María Ruiz', 'maria@cliente.test', '+34 600 300 303'),

  ('33333333-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111',
   'client', 'Pedro Sánchez', 'pedro@cliente.test', '+34 600 300 304'),

  ('33333333-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111',
   'client', 'Laura Torres', 'laura@cliente.test', '+34 600 300 305');


-- ----------- 4. SERVICIOS -------------------------------------

insert into services (id, business_id, name, description, duration_minutes, price)
values
  ('44444444-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'Corte de pelo', 'Corte clásico para hombre o mujer', 30, 18.00),

  ('44444444-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   'Corte + color', 'Corte y aplicación de tinte completo', 90, 55.00),

  ('44444444-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111',
   'Mechas', 'Mechas californianas o tradicionales', 120, 65.00),

  ('44444444-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111',
   'Manicura', 'Manicura clásica con esmaltado', 45, 20.00),

  ('44444444-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111',
   'Pedicura', 'Pedicura con tratamiento hidratante', 50, 25.00),

  ('44444444-0000-0000-0000-000000000006', '11111111-1111-1111-1111-111111111111',
   'Tratamiento capilar', 'Hidratación profunda y mascarilla', 60, 35.00);


-- ----------- 5. ASIGNACIÓN EMPLEADOS-SERVICIOS ----------------
-- Lucía hace todo de pelo. Marcos también pelo. Sofía solo uñas.

insert into employees_services (employee_id, service_id) values
  -- Lucía
  ('22222222-0000-0000-0000-000000000001', '44444444-0000-0000-0000-000000000001'),
  ('22222222-0000-0000-0000-000000000001', '44444444-0000-0000-0000-000000000002'),
  ('22222222-0000-0000-0000-000000000001', '44444444-0000-0000-0000-000000000003'),
  ('22222222-0000-0000-0000-000000000001', '44444444-0000-0000-0000-000000000006'),
  -- Marcos
  ('22222222-0000-0000-0000-000000000002', '44444444-0000-0000-0000-000000000001'),
  ('22222222-0000-0000-0000-000000000002', '44444444-0000-0000-0000-000000000002'),
  ('22222222-0000-0000-0000-000000000002', '44444444-0000-0000-0000-000000000006'),
  -- Sofía
  ('22222222-0000-0000-0000-000000000003', '44444444-0000-0000-0000-000000000004'),
  ('22222222-0000-0000-0000-000000000003', '44444444-0000-0000-0000-000000000005');


-- ----------- 6. PRODUCTOS (inventario) ------------------------

insert into products (id, business_id, sku, name, category, stock, min_stock, price)
values
  ('55555555-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'TIN-0042', 'Tinte rubio ceniza', 'tintes', 2, 10, 12.50),

  ('55555555-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   'TIN-0043', 'Tinte castaño oscuro', 'tintes', 8, 10, 12.50),

  ('55555555-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111',
   'CHA-0012', 'Champú profesional 1L', 'champus', 15, 5, 18.00),

  ('55555555-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111',
   'ACO-0055', 'Acondicionador reparador', 'champus', 22, 5, 14.00),

  ('55555555-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111',
   'MAS-0008', 'Mascarilla hidratante 500ml', 'tratamientos', 4, 8, 22.00),

  ('55555555-0000-0000-0000-000000000006', '11111111-1111-1111-1111-111111111111',
   'ESM-0101', 'Esmalte rojo', 'unas', 12, 6, 6.50),

  ('55555555-0000-0000-0000-000000000007', '11111111-1111-1111-1111-111111111111',
   'ESM-0102', 'Esmalte nude', 'unas', 9, 6, 6.50),

  ('55555555-0000-0000-0000-000000000008', '11111111-1111-1111-1111-111111111111',
   'OXI-0030', 'Oxidante 30 vol', 'tintes', 18, 10, 8.00);


-- ----------- 7. RESERVAS --------------------------------------
-- Mezcla de reservas pasadas (completed), confirmadas próximas y alguna cancelada.

insert into bookings (id, business_id, client_id, employee_id, service_id,
                      start_at, end_at, status, notes)
values
  -- Pasadas COMPLETADAS
  ('66666666-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'c1837a31-cd30-44f9-8619-2d524ba677fe', '22222222-0000-0000-0000-000000000001',
   '44444444-0000-0000-0000-000000000005',
   now() - interval '14 days', now() - interval '14 days' + interval '50 minutes',
   'completed', null),

  ('66666666-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   '33333333-0000-0000-0000-000000000001', '22222222-0000-0000-0000-000000000002',
   '44444444-0000-0000-0000-000000000001',
   now() - interval '10 days', now() - interval '10 days' + interval '30 minutes',
   'completed', 'Cliente habitual, prefiere tijera'),

  ('66666666-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111',
   '33333333-0000-0000-0000-000000000002', '22222222-0000-0000-0000-000000000003',
   '44444444-0000-0000-0000-000000000004',
   now() - interval '7 days', now() - interval '7 days' + interval '45 minutes',
   'completed', null),

  -- Próximas CONFIRMADAS
  ('66666666-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111',
   'c1837a31-cd30-44f9-8619-2d524ba677fe', '22222222-0000-0000-0000-000000000001',
   '44444444-0000-0000-0000-000000000002',
   now() + interval '2 days', now() + interval '2 days' + interval '90 minutes',
   'confirmed', 'Quiere rubio ceniza, comprobar stock'),

  ('66666666-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111',
   '33333333-0000-0000-0000-000000000003', '22222222-0000-0000-0000-000000000002',
   '44444444-0000-0000-0000-000000000001',
   now() + interval '3 days', now() + interval '3 days' + interval '30 minutes',
   'confirmed', null),

  ('66666666-0000-0000-0000-000000000006', '11111111-1111-1111-1111-111111111111',
   '33333333-0000-0000-0000-000000000004', '22222222-0000-0000-0000-000000000003',
   '44444444-0000-0000-0000-000000000005',
   now() + interval '4 days', now() + interval '4 days' + interval '50 minutes',
   'confirmed', null),

  ('66666666-0000-0000-0000-000000000007', '11111111-1111-1111-1111-111111111111',
   '33333333-0000-0000-0000-000000000001', '22222222-0000-0000-0000-000000000001',
   '44444444-0000-0000-0000-000000000003',
   now() + interval '5 days', now() + interval '5 days' + interval '120 minutes',
   'confirmed', 'Mechas californianas'),

  -- Pendientes (sin empleado asignado aún)
  ('66666666-0000-0000-0000-000000000008', '11111111-1111-1111-1111-111111111111',
   '33333333-0000-0000-0000-000000000002', null,
   '44444444-0000-0000-0000-000000000004',
   now() + interval '6 days', now() + interval '6 days' + interval '45 minutes',
   'pending', null),

  -- Cancelada
  ('66666666-0000-0000-0000-000000000009', '11111111-1111-1111-1111-111111111111',
   '33333333-0000-0000-0000-000000000003', '22222222-0000-0000-0000-000000000002',
   '44444444-0000-0000-0000-000000000001',
   now() + interval '1 day', now() + interval '1 day' + interval '30 minutes',
   'cancelled', 'Cliente avisó por whatsapp');


-- ----------- 8. FACTURAS Y LÍNEAS -----------------------------
-- Una factura para cada reserva COMPLETADA.

insert into invoices (id, business_id, client_id, booking_id, number,
                      issued_at, subtotal, tax_amount, total, status)
values
  ('77777777-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'c1837a31-cd30-44f9-8619-2d524ba677fe', '66666666-0000-0000-0000-000000000001', '0001',
   now() - interval '14 days', 20.66, 4.34, 25.00, 'paid'),

  ('77777777-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   '33333333-0000-0000-0000-000000000001', '66666666-0000-0000-0000-000000000002', '0002',
   now() - interval '10 days', 14.88, 3.12, 18.00, 'paid'),

  ('77777777-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111',
   '33333333-0000-0000-0000-000000000002', '66666666-0000-0000-0000-000000000003', '0003',
   now() - interval '7 days', 16.53, 3.47, 20.00, 'pending');

insert into invoice_lines (invoice_id, description, quantity, unit_price, tax_rate)
values
  ('77777777-0000-0000-0000-000000000001', 'Pedicura', 1, 20.66, 21.00),
  ('77777777-0000-0000-0000-000000000002', 'Corte de pelo', 1, 14.88, 21.00),
  ('77777777-0000-0000-0000-000000000003', 'Manicura', 1, 16.53, 21.00);


-- ----------- 9. MOVIMIENTOS DE STOCK --------------------------
-- Algunos movimientos para tener histórico.

insert into stock_movements (product_id, type, quantity, reason, created_by)
values
  ('55555555-0000-0000-0000-000000000001', 'in', 20, 'Compra inicial', '1d646969-cb7b-4e09-8309-3f73eb653451'),
  ('55555555-0000-0000-0000-000000000001', 'out', 18, 'Uso en servicios y ventas', '1d646969-cb7b-4e09-8309-3f73eb653451'),
  ('55555555-0000-0000-0000-000000000003', 'in', 20, 'Reposición', '1d646969-cb7b-4e09-8309-3f73eb653451'),
  ('55555555-0000-0000-0000-000000000003', 'out', 5, 'Uso en lavados', '1d646969-cb7b-4e09-8309-3f73eb653451');


-- ----------- VERIFICACIÓN FINAL -------------------------------
-- Cuenta cuántas filas hay en cada tabla del negocio.
select 'businesses' as tabla, count(*) from businesses
union all select 'profiles', count(*) from profiles
union all select 'services', count(*) from services
union all select 'employees_services', count(*) from employees_services
union all select 'products', count(*) from products
union all select 'bookings', count(*) from bookings
union all select 'invoices', count(*) from invoices
union all select 'invoice_lines', count(*) from invoice_lines
union all select 'stock_movements', count(*) from stock_movements;