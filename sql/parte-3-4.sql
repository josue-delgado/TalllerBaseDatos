SET SERVEROUTPUT ON;

DECLARE
    ex_lote_vencido EXCEPTION;
    
    -- 1. Clientes con pedidos pendientes
    CURSOR c_clientes IS
        SELECT DISTINCT c.cliente_id, c.nombre
        FROM cliente c
        JOIN pedido p ON c.cliente_id = p.cliente_id
        WHERE p.estado = 'PENDIENTE';

    -- 2. Pedidos de un cliente específico
    CURSOR c_pedidos (p_cliente_id NUMBER) IS
        SELECT pedido_id
        FROM pedido
        WHERE cliente_id = p_cliente_id
          AND estado = 'PENDIENTE';

    -- 3. Detalles y lotes asociados a un pedido
    CURSOR c_detalles (p_pedido_id NUMBER) IS
        SELECT d.detalle_id, d.lote_id, l.fecha_vencimiento
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
            END LOOP;
        END LOOP;
    END LOOP;

EXCEPTION
    WHEN ex_lote_vencido THEN
        DBMS_OUTPUT.PUT_LINE('Se intentó procesar un lote con fecha de vencimiento expirada.');
        
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error no controlado: ' || SQLERRM);
END;
/