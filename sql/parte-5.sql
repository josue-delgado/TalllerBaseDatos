CREATE OR REPLACE PACKAGE BODY pkg_distribuidora AS
    FUNCTION fn_calcular_subtotal(
        p_lote_id   IN NUMBER,
        p_cantidad  IN NUMBER
    ) RETURN NUMBER IS
        v_precio_unitario NUMBER(10, 2);
        v_subtotal        NUMBER(12, 2);
    BEGIN
        SELECT p.precio_unitario 
        INTO v_precio_unitario
        FROM lote l
        JOIN producto p ON l.producto_id = p.producto_id
        WHERE l.lote_id = p_lote_id;

        v_subtotal := v_precio_unitario * p_cantidad;
        RETURN v_subtotal;
    END fn_calcular_subtotal;

    PROCEDURE pr_procesar_pedidos IS
        ex_lote_vencido EXCEPTION;
        ex_stock_insuficiente EXCEPTION;
        
        -- Clientes con pedidos pendientes
        CURSOR c_clientes IS
            SELECT DISTINCT c.cliente_id, c.nombre
            FROM cliente c
            JOIN pedido p ON c.cliente_id = p.cliente_id
            WHERE p.estado = 'PENDIENTE';

        -- Pedidos de un cliente específico
        CURSOR c_pedidos (p_cliente_id NUMBER) IS
            SELECT pedido_id
            FROM pedido
            WHERE cliente_id = p_cliente_id
            AND estado = 'PENDIENTE';

        -- Detalles y lotes asociados a un pedido
        CURSOR c_detalles (p_pedido_id NUMBER) IS
            SELECT d.detalle_id, d.lote_id, d.cantidad, l.fecha_vencimiento, l.cantidad_producto
            FROM detalle d
            JOIN lote l ON d.lote_id = l.lote_id
            WHERE d.pedido_id = p_pedido_id;

    BEGIN
        -- Recorre clientes obtenidos 
        FOR reg_cliente IN c_clientes LOOP
            DBMS_OUTPUT.PUT_LINE('Cliente: ' || reg_cliente.nombre);
            -- Recorre pedidos del cliente 
            FOR reg_pedido IN c_pedidos(reg_cliente.cliente_id) LOOP
                DBMS_OUTPUT.PUT_LINE('  -> Pedido ID: ' || reg_pedido.pedido_id);
                -- Recorre detalles y verifica lotes 
                FOR reg_det IN c_detalles(reg_pedido.pedido_id) LOOP
                    -- Evaluar fecha de vencimiento
                    IF reg_det.fecha_vencimiento < SYSDATE THEN
                        RAISE ex_lote_vencido;
                    END IF;
                    
                    -- Evaluar si la cantidad en stock es menor a la solicitada
                    IF reg_det.cantidad_producto < reg_det.cantidad THEN
                        RAISE ex_stock_insuficiente;
                    END IF;
                    
                    -- Descontar cantidad del producto en el lote
                    UPDATE lote
                    SET cantidad_producto = cantidad_producto - reg_det.cantidad
                    WHERE lote_id = reg_det.lote_id;
                END LOOP;

                UPDATE pedido
                SET estado = 'PROCESADO'
                WHERE pedido_id = reg_pedido.pedido_id;

            END LOOP;
        END LOOP;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Proceso finalizado exitosamente.');

    EXCEPTION
        WHEN ex_lote_vencido THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Se intentó procesar un lote con fecha de vencimiento expirada.');
            
        WHEN ex_stock_insuficiente THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Se intentó procesar un pedido con stock insuficiente en el lote.');
            
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error no controlado: ' || SQLERRM);
    END pr_procesar_pedidos;
END pkg_distribuidora;
/

CREATE OR REPLACE TRIGGER trg_bi_detalle_subtotal
BEFORE INSERT ON detalle
FOR EACH ROW
BEGIN
    :NEW.subtotal := pkg_distribuidora.fn_calcular_subtotal(:NEW.lote_id, :NEW.cantidad);
END;
/