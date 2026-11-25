CREATE OR REPLACE PACKAGE pkg_distribuidora AS

    -- Declaración pública de la función para calcular el subtotal
    FUNCTION fn_calcular_subtotal(
        p_lote_id   IN NUMBER,
        p_cantidad  IN NUMBER
    ) RETURN NUMBER;

    -- Declaración pública del procedimiento para procesar pedidos
    PROCEDURE pr_procesar_pedidos;

END pkg_distribuidora;
