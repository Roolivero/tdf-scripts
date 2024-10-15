#!/bin/bash

# Verificar los parámetros
if [ $# -lt 2 ]; then
    echo "Uso: $0 <numero_sucursal> <fecha>"
    exit 1
fi

numero_sucursal=$1
Fecha=$2

# Directorio y archivo de la sucursal
directorio_sucursal="/salud/enviados/transferencias"
archivo_sucursal="$directorio_sucursal/TRANSFERENCIAS-TARJETAS-${numero_sucursal}-${Fecha}.TXT"

echo "Se busca en el directorio: $directorio_sucursal"

# Verificar si el archivo existe
if [ ! -f "$archivo_sucursal" ]; then
    echo "No se encontró el archivo: $archivo_sucursal"
    exit 1
fi

# Contar líneas del archivo
num_lineas=$(wc -l < "$archivo_sucursal")

# Función para determinar el concepto según el código del banco
conceptoBanco() {
    local codigo=$1
    case "$codigo" in
        113) echo "TRANSF.USU BCO.S.CRU" ;;
        117) echo "TRANSF.USU MACRO" ;;
        118) echo "TRANSF.USU NACION" ;;
        *) echo "DESCONOCIDO" ;;
    esac
}

# Función para procesar las transferencias en bloques de 6 líneas
transferencias() {
    contador=0
    instrucciones=""
    lineas_leidas=0

    while IFS=',' read -r sucursal fecha importe codigo_banco banco; do
        # Limpiar variables
        codigo_banco=$(echo "$codigo_banco" | tr -d ' ')
        importe=$(echo "$importe" | tr -d ' ')

        # Generar instrucciones
        instrucciones+="${codigo_banco}"$'\n'
        instrucciones+="$(conceptoBanco "$codigo_banco")"$'\n'
        instrucciones+="G"$'\n'
        instrucciones+="${importe}"$'\n'

        contador=$((contador + 1))
        lineas_leidas=$((lineas_leidas + 1))

        # Si se procesaron 6 líneas, y hay más líneas por leer, abrir una nueva página
        if [ "$lineas_leidas" -lt "$num_lineas" ]; then
            if [ "$contador" -eq 6 ]; then
                instrucciones+="0"$'\n'
                instrucciones+="P"$'\n'
                instrucciones+="A"$'\n'
                instrucciones+="S"$'\n'
                contador=0 
            fi
        fi
    done < "$archivo_sucursal"

    echo "$instrucciones"
}

# Generar las instrucciones
instrucciones=$(transferencias)

# Función para el cierre
fin_comando() {
    instrucciones=""
    lineas_sobrantes=$((num_lineas % 6))
    lineas_vacias=$((6 - lineas_sobrantes))

    # Si las líneas sobrantes son 0, simplemente se cierra con 0,F
    if [ $lineas_sobrantes -eq 0 ]; then
        instrucciones+="0"$'\n'
        instrucciones+="F"$'\n'
    else
        # Agregar líneas vacías si faltan para completar 6
        for ((i=1; i<=lineas_vacias; i++)); do
            instrucciones+=$'\n'
        done
        instrucciones+="0"$'\n'
        instrucciones+="F"$'\n'
    fi
    echo "$instrucciones"
}

# Generar las instrucciones finales
instrucciones_fin=$(fin_comando)

# Ejecutar el runcobol con los datos generados
cd /tdf/prog/onpr
runcobol ca70.int <<EOF
1
70
3
A
S
$numero_sucursal
$Fecha
S
${instrucciones}
${instrucciones_fin}
EOF

if [ $? -ne 0 ]; then
    echo "Error al ejecutar runcobol"
fi

echo "Todos los datos han sido procesados."
