-- ============================================================================
-- Gelato Store — demo seed data
-- ============================================================================
-- Apply after database/schema.sql:
--   psql "$DATABASE_URL" -f database/seed.sql
--
-- Safe to re-run: it truncates every table first, so the database always ends
-- up in exactly this state. All demo accounts share the password "gelato123".
--
-- The data is deliberately *derived* where a rule exists: order line totals come
-- from menu prices plus modifier deltas, stock movements come from the recipes,
-- and low-stock alerts come from real quantities. Re-running this file is
-- therefore also a smoke test that the rules still hold together.
-- ============================================================================

BEGIN;

TRUNCATE TABLE
  stock_movement, stock_alert, stock_threshold, purchase_order_item,
  purchase_order, inventory_lot, order_promotion, payment, order_item_modifier,
  order_item, customer_order, promotion_menu_item, promotion, member,
  branch_menu_item, recipe_requirement, modifier, menu_item, ingredient,
  supplier, staff_session, auth_event, otp_challenge, staff_account, branch
RESTART IDENTITY CASCADE;

-- ---------------------------------------------------------------------------
-- Branches
-- ---------------------------------------------------------------------------
INSERT INTO branch (code, name, address, opened_on) VALUES
  ('Q1', 'Gelato Quận 1',  '128 Nguyễn Huệ, Phường Bến Nghé, Quận 1, TP.HCM',        '2023-03-18'),
  ('Q3', 'Gelato Quận 3',  '42 Võ Văn Tần, Phường 6, Quận 3, TP.HCM',                '2024-06-02'),
  ('TD', 'Gelato Thủ Đức', '9 Đỗ Xuân Hợp, Phường Phước Long B, TP.HCM',             '2025-09-20');

-- ---------------------------------------------------------------------------
-- Staff (7 accounts: 3 managers, 4 staff across the three branches)
-- ---------------------------------------------------------------------------
INSERT INTO staff_account (branch_id, employee_code, full_name, phone, email, role, password_hash)
SELECT b.id, v.employee_code, v.full_name, v.phone, v.email, v.role::staff_role, 'REPLACED_BELOW'
FROM (VALUES
  ('Q1', 'GEL-MGR-001', 'Nguyễn Minh Anh', '+84901000001', 'minhanh@gelato.vn',  'MANAGER'),
  ('Q1', 'GEL-STF-001', 'Trần Quốc Bảo',   '+84901000002', 'quocbao@gelato.vn',  'STAFF'),
  ('Q1', 'GEL-STF-002', 'Lê Thị Chi',      '+84901000003', 'thichi@gelato.vn',   'STAFF'),
  ('Q3', 'GEL-MGR-002', 'Phạm Hoàng Duy',  '+84901000004', 'hoangduy@gelato.vn', 'MANAGER'),
  ('Q3', 'GEL-STF-003', 'Võ Thu Hà',       '+84901000005', 'thuha@gelato.vn',    'STAFF'),
  ('TD', 'GEL-MGR-003', 'Đặng Kim Long',   '+84901000006', 'kimlong@gelato.vn',  'MANAGER'),
  ('TD', 'GEL-STF-004', 'Bùi Thanh Mai',   '+84901000007', 'thanhmai@gelato.vn', 'STAFF')
) AS v(branch_code, employee_code, full_name, phone, email, role)
JOIN branch b ON b.code = v.branch_code;

-- argon2id of "gelato123" (m=65536, t=2, p=1), produced with Bun.password.hash.
UPDATE staff_account
   SET password_hash = '$argon2id$v=19$m=65536,t=2,p=1$nTaw7vGOO/duRjuTfNejtkITp8vIJYE5shv6dath5kM$6aFoZg58ZRSnfS6iYA9XE1lkTGCLi6Rv55ZCHxYr9nU';

-- A few authentication events, so the MFA trail has something in it. Note the
-- shape: password checked, OTP sent, OTP accepted — a session only exists after
-- the third event.
INSERT INTO auth_event (staff_id, type, success, ip, created_at)
SELECT s.id, v.type::auth_event_type, v.success, v.ip::inet, now() - v.ago
FROM (VALUES
  ('+84901000002', 'LOGIN_PASSWORD_OK', true,  '203.0.113.10', interval '3 hours'),
  ('+84901000002', 'OTP_SENT',          true,  '203.0.113.10', interval '3 hours'),
  ('+84901000002', 'OTP_OK',            true,  '203.0.113.10', interval '179 minutes'),
  ('+84901000003', 'LOGIN_PASSWORD_OK', true,  '203.0.113.11', interval '2 hours'),
  ('+84901000003', 'OTP_SENT',          true,  '203.0.113.11', interval '2 hours'),
  ('+84901000003', 'OTP_FAILED',        false, '203.0.113.11', interval '119 minutes'),
  ('+84901000003', 'OTP_FAILED',        false, '203.0.113.11', interval '118 minutes'),
  ('+84901000003', 'OTP_OK',            true,  '203.0.113.11', interval '117 minutes')
) AS v(phone, type, success, ip, ago)
JOIN staff_account s ON s.phone = v.phone;

-- ---------------------------------------------------------------------------
-- Suppliers and ingredients (unit_cost is per ingredient unit, in VND)
-- ---------------------------------------------------------------------------
INSERT INTO supplier (name, phone, email, address) VALUES
  ('Sữa Việt Nam',                '02838220001', 'sales@suavn.example',        '12 Tôn Đức Thắng, Quận 1, TP.HCM'),
  ('Hạt & Hương liệu Sài Gòn',    '02838220002', 'order@hatsaigon.example',    '88 Nguyễn Công Trứ, Quận 1, TP.HCM'),
  ('Bao bì Xanh',                 '02838220003', 'hello@baobixanh.example',    '5 Lý Thường Kiệt, Quận 5, TP.HCM'),
  ('Nông trại Đà Lạt Fresh',      '02633880004', 'farm@dalatfresh.example',    'Thôn 3, Đức Trọng, Lâm Đồng');

INSERT INTO ingredient (name, unit, unit_cost, storage_guidelines, shelf_life_days) VALUES
  ('Sữa tươi nguyên kem',             'ml',    28, 'Bảo quản 2–4°C, dùng trong 7 ngày sau khi mở nắp', 7),
  ('Kem tươi (whipping cream)',       'ml',    90, 'Bảo quản 2–4°C, tối đa 10 ngày',                   10),
  ('Đường mía',                       'g',     25, 'Nơi khô ráo, thoáng mát',                          180),
  ('Hồ trăn Sicily (pistachio paste)','g',    420, 'Bảo quản 2–4°C, tránh ánh sáng',                    60),
  ('Socola đen 70%',                  'g',    320, '18–20°C, độ ẩm dưới 50%',                          120),
  ('Dâu tây Đà Lạt',                  'g',    180, 'Bảo quản 2–4°C, dùng trong 3 ngày',                  3),
  ('Chanh dây (passion fruit purée)', 'g',    150, 'Trữ đông -18°C, rã đông dùng trong 24 giờ',         90),
  ('Vani Bourbon',                    'g',    900, 'Nơi khô ráo, đậy kín',                             365),
  ('Matcha Uji',                      'g',   1200, 'Nơi khô ráo, tránh ánh sáng, dùng trong 90 ngày',    90),
  ('Đế bánh ốc quế',                  'piece', 3500, 'Nơi khô ráo, hộp kín',                             30),
  ('Ly giấy + muỗng',                 'piece', 1200, 'Nơi khô ráo',                                      365),
  ('Hạnh nhân rang',                  'g',    350, 'Nơi khô ráo, hộp kín',                              60),
  ('Sốt caramel',                     'g',    260, 'Bảo quản 2–4°C sau khi mở',                          30),
  ('Trân châu',                       'g',    120, 'Bảo quản 2–4°C, dùng trong 5 ngày',                   5),
  ('Xoài cát Hòa Lộc',                'g',    160, 'Bảo quản 2–4°C, dùng trong 4 ngày',                   4);

-- ---------------------------------------------------------------------------
-- Menu
-- ---------------------------------------------------------------------------
INSERT INTO menu_item (sku, name, description, category, base_price, storage_guidelines) VALUES
  ('GEL-PIS', 'Hồ trăn Sicilia',   'Gelato hồ trăn rang, vị béo hạt, ít ngọt',      'GELATO', 55000, 'Giữ -18°C, làm mềm 5 phút trước khi phục vụ'),
  ('GEL-CHO', 'Socola 70%',        'Gelato socola đen nguyên chất',                 'GELATO', 45000, 'Giữ -18°C, làm mềm 5 phút trước khi phục vụ'),
  ('GEL-STR', 'Dâu tây sữa',       'Gelato dâu tây Đà Lạt tươi theo mùa',           'GELATO', 40000, 'Giữ -18°C, bán trong ngày khi tan'),
  ('SOR-PAS', 'Sorbet chanh dây',  'Sorbet chanh dây không sữa, chua thanh',        'SORBET', 35000, 'Giữ -18°C, bán trong ngày khi tan'),
  ('GEL-MAT', 'Matcha Uji',        'Gelato matcha Uji hảo hạng',                    'GELATO', 50000, 'Giữ -18°C, tránh ánh sáng'),
  ('GEL-VAN', 'Vani Bourbon',      'Gelato vani Bourbon cổ điển',                   'GELATO', 38000, 'Giữ -18°C, làm mềm 5 phút trước khi phục vụ'),
  ('DRK-CAR', 'Sữa lắc caramel',   'Sữa lắc caramel muối, phục vụ lạnh',            'DRINK',  42000, 'Phục vụ ngay, không bảo quản'),
  ('CAK-AFF', 'Affogato',          'Gelato vani chan espresso nóng',                'CAKE',   48000, 'Phục vụ ngay sau khi chan');

-- Recipes: what ONE serving of each item consumes, in ingredient units.
INSERT INTO recipe_requirement (menu_item_id, ingredient_id, quantity)
SELECT mi.id, i.id, v.qty
FROM (VALUES
  ('GEL-PIS', 'Sữa tươi nguyên kem',             60), ('GEL-PIS', 'Kem tươi (whipping cream)', 25),
  ('GEL-PIS', 'Đường mía',                        8), ('GEL-PIS', 'Hồ trăn Sicily (pistachio paste)', 40),
  ('GEL-PIS', 'Đế bánh ốc quế',                   1), ('GEL-PIS', 'Ly giấy + muỗng', 1),

  ('GEL-CHO', 'Sữa tươi nguyên kem',             65), ('GEL-CHO', 'Kem tươi (whipping cream)', 20),
  ('GEL-CHO', 'Đường mía',                       10), ('GEL-CHO', 'Socola đen 70%', 35),
  ('GEL-CHO', 'Đế bánh ốc quế',                   1), ('GEL-CHO', 'Ly giấy + muỗng', 1),

  ('GEL-STR', 'Sữa tươi nguyên kem',             50), ('GEL-STR', 'Kem tươi (whipping cream)', 20),
  ('GEL-STR', 'Đường mía',                       12), ('GEL-STR', 'Dâu tây Đà Lạt', 45),
  ('GEL-STR', 'Ly giấy + muỗng',                  1),

  ('SOR-PAS', 'Đường mía',                       10), ('SOR-PAS', 'Chanh dây (passion fruit purée)', 45),
  ('SOR-PAS', 'Ly giấy + muỗng',                  1),

  ('GEL-MAT', 'Sữa tươi nguyên kem',             60), ('GEL-MAT', 'Kem tươi (whipping cream)', 20),
  ('GEL-MAT', 'Đường mía',                       10), ('GEL-MAT', 'Matcha Uji', 8),
  ('GEL-MAT', 'Đế bánh ốc quế',                   1), ('GEL-MAT', 'Ly giấy + muỗng', 1),

  ('GEL-VAN', 'Sữa tươi nguyên kem',             65), ('GEL-VAN', 'Kem tươi (whipping cream)', 25),
  ('GEL-VAN', 'Đường mía',                       10), ('GEL-VAN', 'Vani Bourbon', 4),
  ('GEL-VAN', 'Đế bánh ốc quế',                   1), ('GEL-VAN', 'Ly giấy + muỗng', 1),

  ('DRK-CAR', 'Sữa tươi nguyên kem',            120), ('DRK-CAR', 'Kem tươi (whipping cream)', 30),
  ('DRK-CAR', 'Đường mía',                        5), ('DRK-CAR', 'Sốt caramel', 25),
  ('DRK-CAR', 'Ly giấy + muỗng',                  1),

  ('CAK-AFF', 'Vani Bourbon',                    40), ('CAK-AFF', 'Sữa tươi nguyên kem', 30),
  ('CAK-AFF', 'Ly giấy + muỗng',                  1)
) AS v(sku, ingredient_name, qty)
JOIN menu_item mi ON mi.sku = v.sku
JOIN ingredient i ON i.name = v.ingredient_name;

-- Modifiers. Sizes are global and carry the serving multiplier; toppings are
-- global price add-ons that also consume stock; the flavour tweak is item-scoped.
INSERT INTO modifier (kind, name, price_delta, servings_multiplier, menu_item_id) VALUES
  ('SIZE',    'Size nhỏ (1 viên)', 0,     1, NULL),
  ('SIZE',    'Size vừa (2 viên)', 15000, 2, NULL),
  ('SIZE',    'Size lớn (3 viên)', 30000, 3, NULL),
  ('TOPPING', 'Hạnh nhân rang',    8000,  1, NULL),
  ('TOPPING', 'Sốt caramel',       6000,  1, NULL),
  ('TOPPING', 'Trân châu',         7000,  1, NULL);

INSERT INTO modifier (kind, name, price_delta, servings_multiplier, menu_item_id)
SELECT 'FLAVOR', 'Vani đậm', 5000, 1, mi.id FROM menu_item mi WHERE mi.sku = 'GEL-VAN';

-- Topping recipes: one order_item_modifier row consumes this much.
INSERT INTO recipe_requirement (modifier_id, ingredient_id, quantity)
SELECT m.id, i.id, v.qty
FROM (VALUES
  ('Hạnh nhân rang', 'Hạnh nhân rang', 10),
  ('Sốt caramel',    'Sốt caramel',    20),
  ('Trân châu',      'Trân châu',      25),
  ('Vani đậm',       'Vani Bourbon',    2)
) AS v(modifier_name, ingredient_name, qty)
JOIN modifier m ON m.name = v.modifier_name
JOIN ingredient i ON i.name = v.ingredient_name;

-- Availability: every branch offers the whole menu, then a couple of real-world
-- exceptions. available_qty is a manual serving count, not derived from stock.
INSERT INTO branch_menu_item (branch_id, menu_item_id, available_qty)
SELECT b.id, mi.id, 40 FROM branch b CROSS JOIN menu_item mi;

UPDATE branch_menu_item bmi
   SET available_qty = 0, is_sold_out = true
  FROM branch b, menu_item mi
 WHERE b.code = 'TD' AND mi.sku = 'GEL-PIS'
   AND bmi.branch_id = b.id AND bmi.menu_item_id = mi.id;

UPDATE branch_menu_item bmi
   SET available_qty = 6
  FROM branch b, menu_item mi
 WHERE b.code = 'Q3' AND mi.sku = 'GEL-MAT'
   AND bmi.branch_id = b.id AND bmi.menu_item_id = mi.id;

-- ---------------------------------------------------------------------------
-- Purchase orders
-- ---------------------------------------------------------------------------
INSERT INTO purchase_order (po_number, branch_id, supplier_id, status, created_by, issued_at, expected_on, received_at)
SELECT v.po_number, b.id, s.id, v.status::po_status, st.id,
       now() - v.issued_ago, (now() - v.issued_ago)::date + v.eta_days,
       CASE WHEN v.status = 'RECEIVED' THEN now() - interval '1 day' END
FROM (VALUES
  ('PO-2026-1104-01', 'Q1', 'Sữa Việt Nam',             'RECEIVED', interval '2 days', 1),
  ('PO-2026-1105-01', 'Q3', 'Hạt & Hương liệu Sài Gòn', 'SENT',     interval '1 day',  2),
  ('PO-2026-1103-02', 'Q1', 'Bao bì Xanh',              'RECEIVED', interval '3 days', 2)
) AS v(po_number, branch_code, supplier_name, status, issued_ago, eta_days)
JOIN branch b ON b.code = v.branch_code
JOIN supplier s ON s.name = v.supplier_name
JOIN staff_account st ON st.branch_id = b.id AND st.role = 'MANAGER';

INSERT INTO purchase_order_item (purchase_order_id, ingredient_id, qty_ordered, qty_received, unit_cost)
SELECT po.id, i.id, v.qty, CASE WHEN po.status = 'RECEIVED' THEN v.qty ELSE 0 END, i.unit_cost
FROM (VALUES
  ('PO-2026-1104-01', 'Sữa tươi nguyên kem',       60000),
  ('PO-2026-1104-01', 'Kem tươi (whipping cream)', 20000),
  ('PO-2026-1105-01', 'Matcha Uji',                 1000),
  ('PO-2026-1105-01', 'Hồ trăn Sicily (pistachio paste)', 3000),
  ('PO-2026-1103-02', 'Ly giấy + muỗng',            2000),
  ('PO-2026-1103-02', 'Đế bánh ốc quế',             1000)
) AS v(po_number, ingredient_name, qty)
JOIN purchase_order po ON po.po_number = v.po_number
JOIN ingredient i ON i.name = v.ingredient_name;

-- ---------------------------------------------------------------------------
-- Inventory lots: one generous batch per branch per ingredient, aged 2 days so
-- expiry dates land in the future. qty_received is the ledger baseline.
-- ---------------------------------------------------------------------------
INSERT INTO inventory_lot (branch_id, ingredient_id, supplier_id, qty_received, qty_remaining,
                           unit_cost, imported_on, expires_on, received_by)
SELECT b.id, i.id, s.id, v.qty, v.qty, i.unit_cost,
       current_date - 2, current_date + i.shelf_life_days - 2, st.id
FROM branch b
CROSS JOIN ingredient i
JOIN supplier s ON s.name = CASE
    WHEN i.name IN ('Đế bánh ốc quế', 'Ly giấy + muỗng')      THEN 'Bao bì Xanh'
    WHEN i.name IN ('Dâu tây Đà Lạt', 'Xoài cát Hòa Lộc')     THEN 'Nông trại Đà Lạt Fresh'
    WHEN i.unit = 'ml'                                        THEN 'Sữa Việt Nam'
    ELSE 'Hạt & Hương liệu Sài Gòn'
  END
JOIN staff_account st ON st.branch_id = b.id AND st.role = 'MANAGER'
CROSS JOIN LATERAL (
  SELECT CASE i.unit WHEN 'piece' THEN 2000.0 WHEN 'ml' THEN 40000.0 ELSE 8000.0 END AS qty
) v;

-- A second, older pistachio batch at Quận 1, to show that stock is per-batch and
-- that consumption follows expiry order.
INSERT INTO inventory_lot (branch_id, ingredient_id, supplier_id, qty_received, qty_remaining,
                           unit_cost, imported_on, expires_on, received_by)
SELECT b.id, i.id, s.id, 900, 900, i.unit_cost, current_date - 40, current_date + 10, st.id
FROM branch b, ingredient i, supplier s, staff_account st
WHERE b.code = 'Q1' AND i.name = 'Hồ trăn Sicily (pistachio paste)'
  AND s.name = 'Hạt & Hương liệu Sài Gòn'
  AND st.branch_id = b.id AND st.role = 'MANAGER';

-- Matcha genuinely ran low at Thủ Đức: this is what raises the low-stock alert.
UPDATE inventory_lot l
   SET qty_received = 40, qty_remaining = 40
  FROM branch b, ingredient i
 WHERE b.code = 'TD' AND i.name = 'Matcha Uji'
   AND l.branch_id = b.id AND l.ingredient_id = i.id;

-- Link the received purchase order to the lots it produced.
UPDATE inventory_lot l
   SET purchase_order_id = po.id
  FROM purchase_order po, branch b
 WHERE po.po_number = 'PO-2026-1104-01'
   AND b.code = 'Q1'
   AND l.branch_id = b.id
   AND l.ingredient_id IN (
     SELECT id FROM ingredient
      WHERE name IN ('Sữa tươi nguyên kem', 'Kem tươi (whipping cream)'));

-- Safety thresholds per branch, for everything that is food (packaging is not
-- a shortage risk). Quantities below the threshold produce an OPEN alert below.
INSERT INTO stock_threshold (branch_id, ingredient_id, safety_qty)
SELECT b.id, i.id, CASE i.unit WHEN 'ml' THEN 5000 ELSE 800 END
FROM branch b CROSS JOIN ingredient i
WHERE i.unit <> 'piece';

-- ---------------------------------------------------------------------------
-- Members and promotions
-- ---------------------------------------------------------------------------
INSERT INTO member (member_code, full_name, phone, email, birthday, points, joined_at) VALUES
  ('MEM-0001', 'Nguyễn Thu Lan',   '0903111222', 'thulan@example.com',  '1996-04-12', 240, now() - interval '400 days'),
  ('MEM-0002', 'Trần Minh Khang',  '0918222333', 'minhkhang@example.com','1991-11-30', 60,  now() - interval '180 days'),
  ('MEM-0003', 'Lê Ngọc Hân',      '0987333444', 'ngochan@example.com',  '2000-07-08', 0,   now() - interval '60 days'),
  ('MEM-0004', 'Phạm Gia Bảo',     '0938444555', 'giabao@example.com',   '1988-02-19', 120, now() - interval '320 days');

INSERT INTO promotion (name, discount_rate, starts_at, ends_at, created_by)
SELECT 'Khai trương Quận 3', 20.00, now() - interval '5 days', now() + interval '9 days', st.id
FROM staff_account st WHERE st.employee_code = 'GEL-MGR-002';

INSERT INTO promotion (name, discount_rate, starts_at, ends_at, created_by)
SELECT 'Happy Hour 14–17h', 15.00, now() - interval '5 days', now() + interval '55 days', st.id
FROM staff_account st WHERE st.employee_code = 'GEL-MGR-001';

INSERT INTO promotion_menu_item (promotion_id, menu_item_id)
SELECT p.id, mi.id
FROM (VALUES
  ('Khai trương Quận 3', 'SOR-PAS'),
  ('Khai trương Quận 3', 'GEL-STR'),
  ('Happy Hour 14–17h',  'DRK-CAR')
) AS v(promotion_name, sku)
JOIN promotion p ON p.name = v.promotion_name
JOIN menu_item mi ON mi.sku = v.sku;

-- ---------------------------------------------------------------------------
-- Orders. Totals start at zero and are derived below; stock is deducted at
-- placement (not at payment), which is why the PLACED order has already moved
-- inventory while its payment is still PENDING.
-- ---------------------------------------------------------------------------
INSERT INTO customer_order (order_no, branch_id, member_id, created_by, status, notes, placed_at, completed_at, cancelled_at)
SELECT v.order_no, b.id, m.id, st.id, v.status::order_status, v.notes,
       now() - v.placed_ago,
       CASE WHEN v.status IN ('COMPLETED') THEN now() - v.placed_ago + interval '12 minutes' END,
       CASE WHEN v.status = 'CANCELLED'  THEN now() - v.placed_ago + interval '4 minutes'  END
FROM (VALUES
  ('GEL-0001', 'Q1', '0903111222', 'GEL-STF-001', 'PLACED',    'Khách quen, ít đá',        interval '90 minutes'),
  ('GEL-0002', 'Q1', NULL,         'GEL-STF-002', 'PAID',      NULL,                       interval '3 hours'),
  ('GEL-0003', 'Q3', '0918222333', 'GEL-STF-003', 'COMPLETED', 'Áp dụng khuyến mãi khai trương', interval '1 day 2 hours'),
  ('GEL-0004', 'Q1', NULL,         'GEL-STF-001', 'CANCELLED', 'Khách đổi ý trước khi phục vụ', interval '1 day 5 hours')
) AS v(order_no, branch_code, member_phone, staff_code, status, notes, placed_ago)
JOIN branch b ON b.code = v.branch_code
LEFT JOIN member m ON m.phone = v.member_phone
JOIN staff_account st ON st.employee_code = v.staff_code;

INSERT INTO order_item (order_id, menu_item_id, quantity, unit_price, line_total, prep_status, notes)
SELECT o.id, mi.id, v.qty, 0, 0, v.prep::prep_status, v.notes
FROM (VALUES
  ('GEL-0001', 'GEL-PIS', 2, 'BLENDING', NULL),
  ('GEL-0001', 'GEL-CHO', 1, 'READY',    NULL),
  ('GEL-0002', 'GEL-MAT', 1, 'RESTING',  'Matcha đậm'),
  ('GEL-0002', 'DRK-CAR', 1, 'READY',    NULL),
  ('GEL-0003', 'SOR-PAS', 3, 'SERVED',   NULL),
  ('GEL-0004', 'GEL-VAN', 1, 'QUEUED',   NULL)
) AS v(order_no, sku, qty, prep, notes)
JOIN customer_order o ON o.order_no = v.order_no
JOIN menu_item mi ON mi.sku = v.sku;

INSERT INTO order_item_modifier (order_item_id, modifier_id, quantity, price_delta)
SELECT oi.id, m.id, v.qty, m.price_delta
FROM (VALUES
  ('GEL-0001', 'GEL-PIS', 'Size vừa (2 viên)', 1),
  ('GEL-0001', 'GEL-PIS', 'Hạnh nhân rang',    1),
  ('GEL-0001', 'GEL-CHO', 'Size nhỏ (1 viên)', 1),
  ('GEL-0001', 'GEL-CHO', 'Sốt caramel',       1),
  ('GEL-0002', 'GEL-MAT', 'Size lớn (3 viên)', 1),
  ('GEL-0002', 'GEL-MAT', 'Trân châu',         1),
  ('GEL-0003', 'SOR-PAS', 'Size nhỏ (1 viên)', 1),
  ('GEL-0004', 'GEL-VAN', 'Vani đậm',          1)
) AS v(order_no, sku, modifier_name, qty)
JOIN customer_order o ON o.order_no = v.order_no
JOIN order_item oi ON oi.order_id = o.id
JOIN menu_item mi ON mi.id = oi.menu_item_id AND mi.sku = v.sku
JOIN modifier m ON m.name = v.modifier_name AND (m.menu_item_id IS NULL OR m.menu_item_id = mi.id);

-- Line price = base price + chosen modifier deltas; the line total follows.
WITH priced AS (
  SELECT oi.id, oi.quantity,
         mi.base_price + COALESCE(SUM(om.price_delta * om.quantity), 0) AS unit_price
  FROM order_item oi
  JOIN menu_item mi ON mi.id = oi.menu_item_id
  LEFT JOIN order_item_modifier om ON om.order_item_id = oi.id
  GROUP BY oi.id, oi.quantity, mi.base_price
)
UPDATE order_item oi
   SET unit_price = p.unit_price,
       line_total = p.unit_price * oi.quantity
  FROM priced p
 WHERE oi.id = p.id;

-- The Quận 3 order earned the launch promotion (20% off the promoted lines).
-- Computed from the lines rather than from customer_order.subtotal, because the
-- order row is not priced yet.
INSERT INTO order_promotion (order_id, promotion_id, discount_amount)
SELECT o.id, p.id, ROUND(SUM(oi.line_total) * p.discount_rate / 100.0, 2)
FROM customer_order o
JOIN order_item oi ON oi.order_id = o.id
JOIN promotion p ON p.name = 'Khai trương Quận 3'
JOIN promotion_menu_item pmi
  ON pmi.promotion_id = p.id AND pmi.menu_item_id = oi.menu_item_id
WHERE o.order_no = 'GEL-0003'
GROUP BY o.id, p.id, p.discount_rate;

-- Subtotal, discount and total are always written in ONE statement: the
-- CHECK (total = subtotal - discount) is not deferrable, so setting subtotal
-- alone would (correctly) fail. Application code must do the same.
UPDATE customer_order o
   SET subtotal = p.subtotal,
       discount = p.discount,
       total    = p.subtotal - p.discount
  FROM (
    SELECT oi.order_id,
           SUM(oi.line_total) AS subtotal,
           COALESCE((SELECT SUM(op.discount_amount)
                       FROM order_promotion op
                      WHERE op.order_id = oi.order_id), 0) AS discount
      FROM order_item oi
     GROUP BY oi.order_id
  ) p
 WHERE o.id = p.order_id;

INSERT INTO payment (order_id, method, status, amount, provider_ref, paid_at)
SELECT o.id, v.method::payment_method, v.status::payment_status, o.total, v.ref,
       CASE WHEN v.status = 'SUCCEEDED' THEN o.placed_at + interval '40 seconds' END
FROM (VALUES
  ('GEL-0001', 'QR_CODE',       'PENDING', NULL),
  ('GEL-0002', 'CREDIT_CARD',   'SUCCEEDED', 'VISA-AUTH-88121'),
  ('GEL-0003', 'BANK_TRANSFER', 'SUCCEEDED', 'VCB-2026-1105-77120'),
  ('GEL-0004', 'CREDIT_CARD',   'FAILED',    'VISA-AUTH-88117')
) AS v(order_no, method, status, ref)
JOIN customer_order o ON o.order_no = v.order_no;

-- ---------------------------------------------------------------------------
-- Stock ledger, generated from the recipes.
--
-- This is the same algorithm the service layer must run inside one transaction:
--   requirements = item recipe x servings (sizes multiply) + topping recipes
--   allocation   = first-expired-first-out, per branch, per ingredient
--   writes       = one stock_movement row per (order line, ingredient), plus a
--                  reversing row for cancelled orders
-- Seeding it from the recipes means demo stock can never disagree with the
-- recipes that produced it.
-- ---------------------------------------------------------------------------
WITH servings AS (
  SELECT oi.id AS order_item_id,
         o.branch_id,
         oi.menu_item_id,
         oi.quantity * COALESCE((
           SELECT m.servings_multiplier
             FROM order_item_modifier om
             JOIN modifier m ON m.id = om.modifier_id
            WHERE om.order_item_id = oi.id AND m.kind = 'SIZE'
            LIMIT 1), 1) AS servings
    FROM order_item oi
    JOIN customer_order o ON o.id = oi.order_id
),
requirements AS (
  SELECT s.order_item_id, s.branch_id, r.ingredient_id, r.quantity * s.servings AS qty
    FROM servings s
    JOIN recipe_requirement r ON r.menu_item_id = s.menu_item_id
  UNION ALL
  SELECT s.order_item_id, s.branch_id, r.ingredient_id, r.quantity * om.quantity
    FROM servings s
    JOIN order_item_modifier om ON om.order_item_id = s.order_item_id
    JOIN recipe_requirement r ON r.modifier_id = om.modifier_id
),
totals AS (
  SELECT order_item_id, branch_id, ingredient_id, SUM(qty) AS qty
    FROM requirements
   GROUP BY order_item_id, branch_id, ingredient_id
),
fefo_lot AS (
  SELECT DISTINCT ON (branch_id, ingredient_id)
         id, branch_id, ingredient_id
    FROM inventory_lot
   WHERE qty_remaining > 0
   ORDER BY branch_id, ingredient_id, expires_on NULLS LAST
)
INSERT INTO stock_movement (inventory_lot_id, branch_id, ingredient_id, delta_qty,
                            reason, order_item_id, note)
SELECT l.id, t.branch_id, t.ingredient_id, -t.qty, 'SALE_CONSUMPTION', t.order_item_id,
       'Seed: xuất kho theo công thức'
  FROM totals t
  JOIN fefo_lot l ON l.branch_id = t.branch_id AND l.ingredient_id = t.ingredient_id;

-- Cancelled orders get their ingredients back, against the same lots.
INSERT INTO stock_movement (inventory_lot_id, branch_id, ingredient_id, delta_qty,
                            reason, order_item_id, note)
SELECT m.inventory_lot_id, m.branch_id, m.ingredient_id, -m.delta_qty, 'ORDER_RESTORE',
       m.order_item_id, 'Seed: hoàn kho khi huỷ đơn ' || o.order_no
  FROM stock_movement m
  JOIN order_item oi ON oi.id = m.order_item_id
  JOIN customer_order o ON o.id = oi.order_id
 WHERE m.reason = 'SALE_CONSUMPTION'
   AND o.status = 'CANCELLED';

UPDATE inventory_lot l
   SET qty_remaining = l.qty_remaining + m.net
  FROM (SELECT inventory_lot_id, SUM(delta_qty) AS net
          FROM stock_movement GROUP BY inventory_lot_id) m
 WHERE l.id = m.inventory_lot_id;

-- ---------------------------------------------------------------------------
-- Low-stock alerts, derived from real quantities vs thresholds.
-- ---------------------------------------------------------------------------
INSERT INTO stock_alert (branch_id, ingredient_id, qty_at_alert, threshold_qty)
SELECT t.branch_id, t.ingredient_id, COALESCE(SUM(l.qty_remaining), 0), t.safety_qty
  FROM stock_threshold t
  LEFT JOIN inventory_lot l
         ON l.branch_id = t.branch_id AND l.ingredient_id = t.ingredient_id
 GROUP BY t.branch_id, t.ingredient_id, t.safety_qty
HAVING COALESCE(SUM(l.qty_remaining), 0) < t.safety_qty;

-- ---------------------------------------------------------------------------
-- Self-check. If the seed data breaks an invariant, fail loudly instead of
-- leaving a database that quietly lies.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  bad_lots int;
BEGIN
  SELECT count(*) INTO bad_lots
    FROM inventory_lot l
   WHERE l.qty_remaining <> l.qty_received + COALESCE(
           (SELECT SUM(m.delta_qty) FROM stock_movement m WHERE m.inventory_lot_id = l.id), 0);

  IF bad_lots > 0 THEN
    RAISE EXCEPTION 'stock ledger does not reconcile on % lot(s)', bad_lots;
  END IF;

  RAISE NOTICE 'Seed OK: % branches, % menu items, % orders, % stock movements, % open alerts',
    (SELECT count(*) FROM branch),
    (SELECT count(*) FROM menu_item),
    (SELECT count(*) FROM customer_order),
    (SELECT count(*) FROM stock_movement),
    (SELECT count(*) FROM stock_alert WHERE status = 'OPEN');
END $$;

COMMIT;
