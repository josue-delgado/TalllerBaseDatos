CREATE OR REPLACE PACKAGE BODY pkg_distribuidora AS

    
    -- Definición de un RECORD para estructurar una línea de auditoría/procesamiento
    TYPE t_registro_item IS RECORD (
        lote_id           lote.lote_id%TYPE,
        nombre_producto   producto.nombre_producto%TYPE,
        cantidad_pedida   detalle.cantidad%TYPE,
        precio_unitario   producto.precio_unitario%TYPE,
        subtotal_calculado NUMBER(12, 2)
    );

    -- Definición de un VARRAY de tamaño 10 para almacenar mensajes de alerta de auditoría
    TYPE t_arr_alertas IS VARRAY(10) OF VARCHAR2(250);

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
        
        -- Declaración de variables basadas en el RECORD y el VARRAY
        v_item_actual  t_registro_item;
        v_listado_log  t_arr_alertas := t_arr_alertas(); -- Inicialización del VARRAY
        v_indice_log   INTEGER := 0;

        -- Cursor de pedidos pendientes
        CURSOR c_pedidos_pendientes IS
            SELECT p.pedido_id, c.nombre AS nombre_cliente
            FROM pedido p
            JOIN cliente c ON p.cliente_id = c.cliente_id
            WHERE p.estado = 'PENDIENTE';

        -- Cursor de detalles de un pedido especifico
        CURSOR c_detalles (p_pedido_id NUMBER) IS
            SELECT d.lote_id, pr.nombre_producto, d.cantidad, pr.precio_unitario,
                   l.fecha_vencimiento, l.cantidad_producto
            FROM detalle d
            JOIN lote l ON d.lote_id = l.lote_id
            JOIN producto pr ON l.producto_id = pr.producto_id
            WHERE d.pedido_id = p_pedido_id;

    BEGIN
        FOR reg_ped IN c_pedidos_pendientes LOOP
            DBMS_OUTPUT.PUT_LINE('Procesando Pedido ID: ' || reg_ped.pedido_id || ' - Cliente: ' || reg_ped.nombre_cliente);
            
            FOR reg_det IN c_detalles(reg_ped.pedido_id) LOOP
                -- Cargar datos en la estructura RECORD personalizada
                v_item_actual.lote_id            := reg_det.lote_id;
                v_item_actual.nombre_producto    := reg_det.nombre_producto;
                v_item_actual.cantidad_pedida    := reg_det.cantidad;
                v_item_actual.precio_unitario    := reg_det.precio_unitario;
                v_item_actual.subtotal_calculado := fn_calcular_subtotal(reg_det.lote_id, reg_det.cantidad);

                -- Validaciones de auditoría
                IF reg_det.fecha_vencimiento < SYSDATE THEN
                    -- Guardar alerta en el VARRAY si hay espacio
                    IF v_listado_log.COUNT < v_listado_log.LIMIT THEN
                        v_listado_log.EXTEND;
                        v_listado_log(v_listado_log.COUNT) := 'ALERTA: Lote ' || v_item_actual.lote_id || ' (' || v_item_actual.nombre_producto || ') VENCIDO.';
                    END IF;
                    RAISE ex_lote_vencido;
                END IF;

                IF reg_det.cantidad_producto < v_item_actual.cantidad_pedida THEN
                    RAISE ex_stock_insuficiente;
                END IF;

                -- Descontar stock del lote procesado
                UPDATE lote
                SET cantidad_producto = cantidad_producto - v_item_actual.cantidad_pedida
                WHERE lote_id = v_item_actual.lote_id;

                DBMS_OUTPUT.PUT_LINE('  -> Producto: ' || v_item_actual.nombre_producto || 
                                     ' | Subtotal: $' || v_item_actual.subtotal_calculado);
            END LOOP;

            -- Actualizar estado a PROCESADO
            UPDATE pedido
            SET estado = 'PROCESADO'
            WHERE pedido_id = reg_ped.pedido_id;

        END LOOP;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('=== Proceso finalizado con éxito ===');

        -- Imprimir contenido almacenado en el VARRAY (Log de Auditoría)
        IF v_listado_log.COUNT > 0 THEN
            DBMS_OUTPUT.PUT_LINE('--- Mensajes del VARRAY de Auditoría ---');
            FOR i IN 1..v_listado_log.COUNT LOOP
                DBMS_OUTPUT.PUT_LINE(v_listado_log(i));
            END LOOP;
        END IF;

    EXCEPTION
        WHEN ex_lote_vencido THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('[ERROR EXCEPCIÓN] Lote vencido detectado al procesar.');
        WHEN ex_stock_insuficiente THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('[ERROR EXCEPCIÓN] Stock insuficiente en el lote.');
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('[ERROR GENERAL] ' || SQLERRM);
    END pr_procesar_pedidos;

END pkg_distribuidora;
