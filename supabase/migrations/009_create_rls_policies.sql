-- Row Level Security Policies for Sari-Sari Store

-- Helper function to get the current user's role from the profiles table
CREATE OR REPLACE FUNCTION get_my_role() RETURNS TEXT AS $$
  SELECT role FROM profiles WHERE firebase_uid = auth.jwt() ->> 'sub';
$$ LANGUAGE sql STABLE;

-- 1. PROFILES
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public profiles are viewable by authenticated users." ON profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can update own profile." ON profiles FOR UPDATE TO authenticated USING (auth.jwt() ->> 'sub' = firebase_uid);
CREATE POLICY "Admins can manage all profiles." ON profiles FOR ALL TO authenticated USING (get_my_role() IN ('admin', 'owner'));

-- 2. CATEGORIES
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Categories are viewable by everyone." ON categories FOR SELECT TO authenticated USING (true);
CREATE POLICY "Only admins and owners can manage categories." ON categories FOR ALL TO authenticated USING (get_my_role() IN ('admin', 'owner'));

-- 3. PRODUCTS
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Products are viewable by everyone." ON products FOR SELECT TO authenticated USING (true);
CREATE POLICY "Only admins and owners can manage products." ON products FOR ALL TO authenticated USING (get_my_role() IN ('admin', 'owner'));

-- 4. PRODUCT BATCHES
ALTER TABLE product_batches ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Batches are viewable by staff." ON product_batches FOR SELECT TO authenticated USING (get_my_role() IN ('admin', 'owner', 'employee'));
CREATE POLICY "Only admins and owners can manage batches." ON product_batches FOR ALL TO authenticated USING (get_my_role() IN ('admin', 'owner'));

-- 5. INVENTORY TRANSACTIONS
ALTER TABLE inventory_transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Transactions are viewable by staff." ON inventory_transactions FOR SELECT TO authenticated USING (get_my_role() IN ('admin', 'owner', 'employee'));
CREATE POLICY "Staff can record transactions." ON inventory_transactions FOR INSERT TO authenticated WITH CHECK (get_my_role() IN ('admin', 'owner', 'employee'));

-- 6. ORDERS
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can view all orders." ON orders FOR SELECT TO authenticated USING (get_my_role() IN ('admin', 'owner', 'employee'));
CREATE POLICY "Customers can view own orders." ON orders FOR SELECT TO authenticated USING (user_id = (SELECT id FROM profiles WHERE firebase_uid = auth.jwt() ->> 'sub'));
CREATE POLICY "Staff can manage orders." ON orders FOR ALL TO authenticated USING (get_my_role() IN ('admin', 'owner', 'employee'));

-- 7. ORDER ITEMS
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Items are viewable by those who can view the order." ON order_items FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM orders WHERE orders.id = order_id)
);
CREATE POLICY "Staff can manage order items." ON order_items FOR ALL TO authenticated USING (get_my_role() IN ('admin', 'owner', 'employee'));

-- 8. PRE-ORDERS
ALTER TABLE pre_orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can view all pre-orders." ON pre_orders FOR SELECT TO authenticated USING (get_my_role() IN ('admin', 'owner', 'employee'));
CREATE POLICY "Customers can view own pre-orders." ON pre_orders FOR SELECT TO authenticated USING (user_id = (SELECT id FROM profiles WHERE firebase_uid = auth.jwt() ->> 'sub'));
CREATE POLICY "Staff can manage pre-orders." ON pre_orders FOR ALL TO authenticated USING (get_my_role() IN ('admin', 'owner', 'employee'));

-- 9. SHIPMENTS
ALTER TABLE shipments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can view all shipments." ON shipments FOR SELECT TO authenticated USING (get_my_role() IN ('admin', 'owner', 'employee'));
CREATE POLICY "Customers can view own shipments." ON shipments FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM orders WHERE orders.id = order_id AND orders.user_id = (SELECT id FROM profiles WHERE firebase_uid = auth.jwt() ->> 'sub'))
);
CREATE POLICY "Staff can manage shipments." ON shipments FOR ALL TO authenticated USING (get_my_role() IN ('admin', 'owner', 'employee'));
