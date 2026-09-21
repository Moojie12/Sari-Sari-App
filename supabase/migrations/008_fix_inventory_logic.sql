-- Fix references and implement atomic inventory logic

-- 1. Fix orders table
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_user_id_fkey;
ALTER TABLE orders ALTER COLUMN user_id TYPE uuid USING user_id::uuid;
ALTER TABLE orders ADD CONSTRAINT orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id);

-- 2. Fix pre_orders table
ALTER TABLE pre_orders DROP CONSTRAINT IF EXISTS pre_orders_user_id_fkey;
ALTER TABLE pre_orders ALTER COLUMN user_id TYPE uuid USING user_id::uuid;
ALTER TABLE pre_orders ADD CONSTRAINT pre_orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id);

-- 3. Atomic Sale Transaction Function
CREATE OR REPLACE FUNCTION create_sale_transaction(
    p_firebase_uid TEXT,
    p_order_number TEXT,
    p_total_amount NUMERIC,
    p_total_items INTEGER,
    p_customer_name TEXT,
    p_customer_contact TEXT,
    p_delivery_address TEXT,
    p_order_notes TEXT,
    p_items JSONB -- [{product_id, quantity, unit_price}]
) RETURNS UUID AS $$
DECLARE
    v_profile_id UUID;
    v_order_id UUID;
    v_item RECORD;
    v_batch RECORD;
    v_remaining_qty NUMERIC;
    v_qty_to_deduct NUMERIC;
BEGIN
    -- Get Profile ID from Firebase UID
    SELECT id INTO v_profile_id FROM profiles WHERE firebase_uid = p_firebase_uid;
    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Profile not found for firebase_uid %', p_firebase_uid;
    END IF;

    -- Create Order
    INSERT INTO orders (user_id, order_number, total_amount, total_items, customer_name, customer_contact, delivery_address, order_notes, status)
    VALUES (v_profile_id, p_order_number, p_total_amount, p_total_items, p_customer_name, p_customer_contact, p_delivery_address, p_order_notes, 'completed')
    RETURNING id INTO v_order_id;

    -- Process each item
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(product_id UUID, quantity NUMERIC, unit_price NUMERIC)
    LOOP
        -- Insert Order Item
        INSERT INTO order_items (order_id, product_id, product_name, quantity, unit_price, total_price)
        SELECT v_order_id, v_item.product_id, name, v_item.quantity, v_item.unit_price, v_item.quantity * v_item.unit_price
        FROM products WHERE id = v_item.product_id;

        -- FEFO Stock Deduction
        v_remaining_qty := v_item.quantity;

        WHILE v_remaining_qty > 0 LOOP
            -- Find earliest expiring batch with stock
            -- FOR UPDATE locks the row to prevent race conditions
            SELECT * INTO v_batch
            FROM product_batches
            WHERE product_id = v_item.product_id AND quantity > 0
            ORDER BY expiry_date ASC NULLS LAST, received_date ASC
            FOR UPDATE
            LIMIT 1;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Insufficient stock for product %', v_item.product_id;
            END IF;

            v_qty_to_deduct := LEAST(v_remaining_qty, v_batch.quantity);

            -- Deduct from batch
            UPDATE product_batches
            SET quantity = quantity - v_qty_to_deduct, updated_at = now()
            WHERE id = v_batch.id;

            -- Record Inventory Transaction
            INSERT INTO inventory_transactions (product_id, product_batch_id, transaction_type, quantity, unit_price, total_amount, issued_to, reference_number, notes)
            VALUES (v_item.product_id, v_batch.id, 'sale', v_qty_to_deduct, v_item.unit_price, v_qty_to_deduct * v_item.unit_price, p_customer_name, p_order_number, 'Sale transaction');

            v_remaining_qty := v_remaining_qty - v_qty_to_deduct;
        END LOOP;
    END LOOP;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Atomic Pre-Order Transaction Function
CREATE OR REPLACE FUNCTION create_preorder_transaction(
    p_firebase_uid TEXT,
    p_order_number TEXT,
    p_total_amount NUMERIC,
    p_total_items INTEGER,
    p_customer_name TEXT,
    p_customer_contact TEXT,
    p_delivery_address TEXT,
    p_order_notes TEXT,
    p_expected_date DATE,
    p_items JSONB -- [{product_id, quantity, unit_price}]
) RETURNS UUID AS $$
DECLARE
    v_profile_id UUID;
    v_preorder_id UUID;
    v_item RECORD;
    v_batch RECORD;
    v_remaining_qty NUMERIC;
    v_qty_to_deduct NUMERIC;
BEGIN
    -- Get Profile ID from Firebase UID
    SELECT id INTO v_profile_id FROM profiles WHERE firebase_uid = p_firebase_uid;
    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Profile not found for firebase_uid %', p_firebase_uid;
    END IF;

    -- Create Pre-Order
    INSERT INTO pre_orders (user_id, order_number, total_amount, total_items, customer_name, customer_contact, delivery_address, order_notes, expected_date, status)
    VALUES (v_profile_id, p_order_number, p_total_amount, p_total_items, p_customer_name, p_customer_contact, p_delivery_address, p_order_notes, p_expected_date, 'active')
    RETURNING id INTO v_preorder_id;

    -- Process each item
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(product_id UUID, quantity NUMERIC, unit_price NUMERIC)
    LOOP
        -- Insert Pre-Order Item
        INSERT INTO pre_order_items (pre_order_id, product_id, product_name, quantity, unit_price, total_price)
        SELECT v_preorder_id, v_item.product_id, name, v_item.quantity, v_item.unit_price, v_item.quantity * v_item.unit_price
        FROM products WHERE id = v_item.product_id;

        -- If pre-orders deduct stock immediately, use FEFO logic here
        -- (Optional: based on business rules, pre-orders might just be reservations)
        -- The existing Flutter code implies they DO record transactions, so we'll deduct.
        v_remaining_qty := v_item.quantity;

        WHILE v_remaining_qty > 0 LOOP
            SELECT * INTO v_batch
            FROM product_batches
            WHERE product_id = v_item.product_id AND quantity > 0
            ORDER BY expiry_date ASC NULLS LAST, received_date ASC
            FOR UPDATE
            LIMIT 1;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Insufficient stock for pre-order product %', v_item.product_id;
            END IF;

            v_qty_to_deduct := LEAST(v_remaining_qty, v_batch.quantity);

            UPDATE product_batches
            SET quantity = quantity - v_qty_to_deduct, updated_at = now()
            WHERE id = v_batch.id;

            INSERT INTO inventory_transactions (product_id, product_batch_id, transaction_type, quantity, unit_price, total_amount, issued_to, reference_number, notes)
            VALUES (v_item.product_id, v_batch.id, 'sale', v_qty_to_deduct, v_item.unit_price, v_qty_to_deduct * v_item.unit_price, p_customer_name, p_order_number, 'Pre-order transaction');

            v_remaining_qty := v_remaining_qty - v_qty_to_deduct;
        END LOOP;
    END LOOP;

    RETURN v_preorder_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Convert Pre-Order to Order Function
CREATE OR REPLACE FUNCTION convert_preorder_to_order(
    p_preorder_id UUID,
    p_order_number TEXT
) RETURNS UUID AS $$
DECLARE
    v_preorder RECORD;
    v_order_id UUID;
BEGIN
    -- 1. Get Pre-Order
    SELECT * INTO v_preorder FROM pre_orders WHERE id = p_preorder_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pre-order not found';
    END IF;

    IF v_preorder.status = 'completed' THEN
        RAISE EXCEPTION 'Pre-order already completed';
    END IF;

    -- 2. Create Order (Note: stock was already deducted at pre-order creation)
    INSERT INTO orders (user_id, order_number, total_amount, total_items, customer_name, customer_contact, delivery_address, order_notes, status)
    VALUES (v_preorder.user_id, p_order_number, v_preorder.total_amount, v_preorder.total_items, v_preorder.customer_name, v_preorder.customer_contact, v_preorder.delivery_address, v_preorder.order_notes, 'pending')
    RETURNING id INTO v_order_id;

    -- 3. Copy items
    INSERT INTO order_items (order_id, product_id, product_name, quantity, unit_price, total_price)
    SELECT v_order_id, product_id, product_name, quantity, unit_price, total_price
    FROM pre_order_items WHERE pre_order_id = p_preorder_id;

    -- 4. Mark Pre-Order as completed
    UPDATE pre_orders SET status = 'completed', updated_at = now() WHERE id = p_preorder_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
