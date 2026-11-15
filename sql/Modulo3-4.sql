SET SERVEROUTPUT ON;

DECLARE
    e_pedido_sin_detalles EXCEPTION;
    e_lote_proximo_vencer EXCEPTION;
    
    v_total_pedido  NUMBER(12,2) := 0;
    v_cont_detalles NUMBER := 0;

    -- CURSOR 1: Trae los pedidos con los datos del cliente
    CURSOR c_pedidos IS
        SELECT p.pedido_id,p.fecha_pedido,p.estado,
            c.nombre AS nombre_cliente,c.rut
        FROM pedido p
        JOIN cliente c ON p.cliente_id = c.cliente_id
        ORDER BY p.pedido_id;

    -- CURSOR 2: Trae los detalles del pedido y la fecha del lote
    CURSOR c_detalles_pedido (p_id_pedido NUMBER) IS
        SELECT 
            d.detalle_id, d.cantidad, d.subtotal, prod.nombre_producto, l.lote_id, l.fecha_vencimiento
        FROM detalle d
        JOIN lote l ON d.lote_id = l.lote_id
        JOIN producto prod ON l.producto_id = prod.producto_id
        WHERE d.pedido_id = p_id_pedido;

BEGIN
    DBMS_OUTPUT.PUT_LINE('=== INFORME DE REVISIÓN DE PEDIDOS Y DETALLES ===');

    -- BUCLE ANIDADO 1: Recorre cada pedido
    FOR r_ped IN c_pedidos LOOP
        v_total_pedido := 0;
        v_cont_detalles := 0;

        DBMS_OUTPUT.PUT_LINE(CHR(10) || 'Pedido N°: ' || r_ped.pedido_id || 
                             ' | Cliente: ' || r_ped.nombre_cliente || 
                             ' | RUT: ' || r_ped.rut || 
                             ' | Estado: ' || r_ped.estado);

        -- BUCLE ANIDADO 2: Recorre los productos de ese pedido usando el parámetro
        FOR r_det IN c_detalles_pedido(r_ped.pedido_id) LOOP
            v_cont_detalles := v_cont_detalles + 1;
            v_total_pedido := v_total_pedido + r_det.subtotal;
            
            IF r_det.fecha_vencimiento <= SYSDATE + 7 THEN
                RAISE e_lote_proximo_vencer;
            END IF;

            DBMS_OUTPUT.PUT_LINE('  -> Producto: ' || r_det.nombre_producto || 
                                 ' | Cantidad: ' || r_det.cantidad || 
                                 ' | Lote N°: ' || r_det.lote_id || 
                                 ' | Vencimiento: ' || TO_CHAR(r_det.fecha_vencimiento, 'DD/MM/YYYY') ||
                                 ' | Subtotal: $' || r_det.subtotal);
        END LOOP;

        IF v_cont_detalles = 0 THEN
            RAISE e_pedido_sin_detalles;
        END IF;

        DBMS_OUTPUT.PUT_LINE('Total a pagar del Pedido: $' || v_total_pedido);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== PROCESO FINALIZADO CON ÉXITO ===');

EXCEPTION
    WHEN e_lote_proximo_vencer THEN
        DBMS_OUTPUT.PUT_LINE('Error Se detuvo el procesamiento: Se detectó un producto de un lote vencido o por vencer en menos de 7 días.');

    WHEN e_pedido_sin_detalles THEN
        DBMS_OUTPUT.PUT_LINE('Error Se encontró un pedido registrado que no contiene productos asociados en detalle.');

    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Error No se encontraron registros en las tablas.');
        
    WHEN ZERO_DIVIDE THEN
        DBMS_OUTPUT.PUT_LINE('Error Se intentó realizar una división por cero en el cálculo.');

    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error Código: ' || SQLCODE || ' - Mensaje: ' || SQLERRM);
END;
/