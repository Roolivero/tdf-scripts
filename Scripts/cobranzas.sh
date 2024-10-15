#!/bin/bash

# Verificar los parámetros
if [ $# -lt 2 ]; then
    echo "Uso: $0 <numero_sucursal> <fecha>"
    exit 1
fi

numero_sucursal=$1
Fecha=$2

# Remover espacios en blanco de las variables por si acaso
numero_sucursal=$(echo "$numero_sucursal" | tr -d '[:space:]')
Fecha=$(echo "$Fecha" | tr -d '[:space:]')

echo "La sucursal es: $numero_sucursal"
echo "La fecha es: $Fecha" 

# Directorio y archivo de la sucursal
directorio_sucursal="/salud/enviados/transferencias"
archivo_sucursal="$directorio_sucursal/PAGDEB-TARJETAS-${numero_sucursal}-${Fecha}.TXT"

echo "Se busca en el directorio: $directorio_sucursal"

# Verificar si el archivo existe
if [ ! -f "$archivo_sucursal" ]; then
    echo "No se encontró el archivo: $archivo_sucursal"
    exit 1
fi

directorio_destino="/d1/tdf/prog/db"

# Mover el archivo al directorio de destino
cp "$archivo_sucursal" "$directorio_destino/"
if [ $? -eq 0 ]; then
    echo "Archivo movido exitosamente a $directorio_destino."
else
    echo "Error al mover el archivo."
fi

# Mostrar los valores que se pasarán al runcobol para depuración
echo "Valores que se pasan a runcobol:"
echo "Sucursal: $numero_sucursal"
echo "Fecha: $Fecha"

# Ejecutar el runcobol con los datos generados
cd /d1/tdf/prog/onpr
runcobol ca01t.int <<-EOF
$numero_sucursal
$Fecha
99000070
ca8
1
EOF

if [ $? -ne 0 ]; then
    echo "Error al ejecutar runcobol"
else 
    echo "Todos los datos han sido procesados."
fi
# Eliminar el archivo del directorio de destino
#rm "$directorio_destino/PAGDEB-TARJETAS-${numero_sucursal}-${fecha}.TXT"

# Comprobar si la eliminación fue exitosa
#if [ $? -eq 0 ]; then
#    echo "Archivo eliminado exitosamente de $directorio_destino."
#else
#    echo "Error al eliminar el archivo de $directorio_destino."
#fi

