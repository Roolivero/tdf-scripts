#!/bin/bash

#Parte del script para las Transferencias

# Directorio donde se encuentran los archivos
directorio="/public/Ariel/Rocio/archivos"
directorio_destino="/public/Ariel/Rocio/archivosSuc"
fecha_del_dia=$(date +"%d%m%y")
echo "La fecha es: $fecha_del_dia"

echo "Buscando en directorio: $directorio"
echo "Patrón de búsqueda: *-banco.csv"



# Inicializar un array para realizar seguimiento de sucursales procesadas
declare -A sucursales_presentes_banco

# Buscar el archivo que coincide con el patrón "id_archivo_fecha-banco.csv"
archivo_banco=$(find "$directorio" -type f -name '*-banco.csv' 2>/dev/null)


# Verificar si se encontró algún archivo
if [ -z "$archivo_banco" ]; then
    echo "No se encontró ningún archivo con el formato id_archivo_fecha-banco.csv"
    exit 1
else 
    echo "Procesando el archivo: $archivo_banco"
fi


# Imprimir el contenido del archivo de banco para debug
echo "Contenido del archivo $archivo_banco:"
while IFS=';' read -r sucursal fecha importe codigo_banco banco
do
    echo "Sucursal: $sucursal, Fecha: $fecha, Importe: $importe, Código Banco: $codigo_banco, Banco: $banco"
done < "$archivo_banco"

# Inicializar un array para realizar seguimiento de sucursales procesadas
declare -A sucursales_presentes_banco
hora_actual=$(date +"%H%M%S")  # Obtener timestamp
# Leer el archivo CSV de transferencias línea por línea
while IFS=';' read -r sucursal fecha importe codigo_banco banco
do
    sucursal_num=$sucursal  # Mantener el valor original

    # Verificar si la sucursal está dentro del rango válido
    if [[ $sucursal_num -ge 1 && $sucursal_num -le 17 ]]; then
        # Mostrar la línea que se está procesando
        echo -e "\nLínea: $sucursal;$fecha;$importe;$codigo_banco;$banco\n"

        # Determinar el nombre del archivo para la sucursal actual con timestamp
        archivo_suc_banco="$directorio_destino/TRANSFERENCIAS-TARJETAS-$sucursal_num-${fecha_del_dia}-${hora_actual}.TXT"

        # Si el archivo no existe, inicializarlo con un encabezado
        if [ -z "${sucursales_presentes_banco[$sucursal_num]}" ]; then
            echo "Creando archivo para la sucursal $sucursal_num: $archivo_suc_banco"
            # Inicializar el archivo con un encabezado
            echo "Sucursal;Fecha;Importe;Código Banco;Banco" > "$archivo_suc_banco"
            # Marcar la sucursal como procesada
            sucursales_presentes_banco[$sucursal_num]=1
        fi
        
        # Agregar la línea en el archivo correspondiente a la sucursal
        echo "Abriendo archivo para guardar datos: $archivo_suc_banco"
        echo "$sucursal;$fecha;$importe;$codigo_banco;$banco" >> "$archivo_suc_banco"

        # Imprimir el contenido del archivo después de agregar la línea
        echo "Contenido del archivo de la sucursal $sucursal_num modificado:"
        cat "$archivo_suc_banco"  # Muestra el contenido actual del archivo
    else
        echo "Línea inválida o fuera de rango: $sucursal;$fecha;$importe;$codigo_banco;$banco" >> error.log
    fi
done < "$archivo_banco"

# Concatenar todos los archivos de transferencias al final del día (a las 18)
hora_actual=$(date +"%H")
if [ "$hora_actual" -ge 18 ]; then
    echo "Concatenando archivos de transferencias..."

    # Concatenamos los archivos para cada sucursal
    for sucursal in $(seq -w 1 17); do
        archivo_final="$directorio_destino/TRANSFERENCIAS-TARJETAS-${sucursal}-${fecha_del_dia}.TXT"

        # Usar cat para concatenar los archivos correspondientes
        cat $directorio_destino/TRANSFERENCIAS-TARJETAS-${sucursal}-${fecha_del_dia}-*.TXT > "$archivo_final"
        
        echo "Archivo concatenado para la sucursal $sucursal: $archivo_final"
    done
else
    echo "No es hora de concatenar archivos de transferencias aún."
fi

#Parte del script para las cobranzas
echo "Patrón de búsqueda: *-caja.csv"

# Buscar el archivo que coincide con el patrón "id_archivo_fecha-caja.csv"
archivo_caja=$(find "$directorio" -type f -name '*-caja.csv' 2>/dev/null)

# Verificar si se encontró algún archivo
if [ -z "$archivo_caja" ]; then
    echo "No se encontró ningún archivo con el formato id_archivo_fecha-caja.csv"
    exit 1
fi

echo "Procesando el archivo: $archivo_caja"

# Inicializar un array para realizar seguimiento de sucursales procesadas
declare -A sucursales_presentes_caja

# Imprimir el contenido del archivo para debug
echo "Contenido del archivo $archivo_caja:"
while IFS=';' read -r sucursal suc numero apellido_nombre importe fecha
do
    echo "Sucursal: $sucursal, Suc: $suc, Número: $numero, Nombre: $apellido_nombre, Importe: $importe, Fecha: $fecha"
done < "$archivo_caja"


# Leer el archivo CSV línea por línea
while IFS=';' read -r sucursal suc numero apellido_nombre importe fecha
do
    # Eliminar el prefijo '0' antes de procesar
    sucursal_num=${sucursal#0}
    
    # Verificar si la sucursal está dentro del rango válido
    if [[ $sucursal_num -ge 1 && $sucursal_num -le 17 ]]; then
        # Mostrar la línea que se está procesando
        echo -e "\nLínea: $sucursal;$suc;$numero;$apellido_nombre;$importe;$fecha\n"

        # Determinar el nombre del archivo para la sucursal actual
        archivo_suc_caja="$directorio_destino/PAGDEB-TARJETAS-$sucursal-${fecha_del_dia}.TXT"

        if [ -z "${sucursales_presentes_caja[$sucursal]}" ]; then
            echo "Creando archivo para la sucursal $sucursal: $archivo_suc_caja"
            # Marcar la sucursal como procesada
            sucursales_presentes_caja[$sucursal]=1
        fi
        # Agregar la línea en el archivo correspondiente a la sucursal
        echo "Abriendo archivo para guardar datos: $archivo_suc_caja"
        echo "$sucursal;$suc;$numero;$apellido_nombre;$importe;$fecha" >> "$archivo_suc_caja"

        # Imprimir el contenido del archivo después de agregar la línea
        echo "Contenido del archivo de la sucursal $sucursal_num modificado:"
        cat "$archivo_suc_caja"  # Muestra el contenido actual del archivo
    else
        echo "Línea inválida o fuera de rango: $sucursal;$suc;$numero;$apellido_nombre;$importe;$fecha" >> error.log
    fi
done < "$archivo_caja"

echo "Archivos temporales creados en el directorio $directorio_destino"


#Ejecutar enviar-sucursales.sh automáticamente al final
echo -e "\nEjecutando enviar-sucursales.sh...\n"
./enviar_sucursales.sh