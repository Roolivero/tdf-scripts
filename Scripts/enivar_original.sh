#!/bin/bash

# Directorio donde se encuentran los archivos TXT
directorio_archivos="/public/Ariel/Rocio/archivosSuc"
echo -e "\nLos archivos se buscan en: $directorio_archivos\n"

# Configuración del usuario SFTP
usuario_sftp="reduser"
directorio_destino_sftp="/salud/enviados/transferencias"
usuario_remoto='karina'
usuario_remoto_suc14='kharina'
contrasena='XFVBWXNDCxQLBw=='

# Diccionario de sucursales y sus dominios
declare -A sucursales
sucursales=(
    ["01"]="ush" ["02"]="rgd" ["03"]="rgl" ["04"]="psc" ["05"]="lpb"
    ["06"]="sjn" ["07"]="ggr" ["08"]="rtu" ["09"]="cft" ["10"]="cal"
    ["11"]="28n" ["12"]="ptd" ["14"]="ptr" ["15"]="lhs" ["16"]="pmo"
    ["17"]="lan"
)



echo -e "\nAgrupando archivos por numero de sucursal\n"
# Agrupar archivos por sucursal

echo "Los archivos en el directorio son:"
for archivo in "$directorio_archivos"/*; do
    echo "Archivo: $archivo"
done

# Crear un directorio temporal para agrupar los archivos
temp_dir=$(mktemp -d)


# Limpiar el directorio temporal antes de comenzar
echo "Limpiando el directorio temporal: $temp_dir"
rm -rf "$temp_dir"/*

# Inicializar un array para rastrear los archivos copiados
declare -A archivos_copiados

# Procesar los archivos de PAGDEB y TRANSFERENCIAS
for tipo in PAGDEB TRANSFERENCIAS; do
    if [ "$tipo" = "TRANSFERENCIAS" ]; then
        # Buscar con ambos patrones
        patrones=("TRANSFERENCIAS-TARJETAS-*-*-*.TXT" "TRANSFERENCIAS-TARJETAS-*-*.TXT")
    else
        # Para PAGDEB, un solo patrón
        patrones=("${tipo}-TARJETAS-*-*.TXT")
    fi

    # Iterar sobre los patrones definidos
    for patron in "${patrones[@]}"; do
        echo "Buscando archivos de tipo: $tipo con patrón: $patron"

        for archivo in $directorio_archivos/$patron; do
            if [ -f "$archivo" ]; then
                nombre_archivo=$(basename "$archivo")
                
                # Extraer el número de sucursal del nombre del archivo
                sucursal_num=$(echo "$nombre_archivo" | cut -d'-' -f3)

                echo "Encontrado archivo: $archivo"
                echo "Sucursal extraída: $sucursal_num"

                # Verificar si ya se ha creado el directorio para la sucursal
                if [ -z "${directorios_sucursales[$sucursal_num]}" ]; then
                    # Crear el directorio para la sucursal si no existe
                    mkdir -p "$temp_dir/$sucursal_num"
                    directorios_sucursales[$sucursal_num]=1  # Marcar que ya se creó el directorio
                    echo "Directorio creado para la sucursal $sucursal_num: $temp_dir/$sucursal_num"
                else
                    echo "El directorio ya existe para la sucursal $sucursal_num: $temp_dir/$sucursal_num"
                fi

                # Verificar si el archivo ya ha sido copiado
                if [ -z "${archivos_copiados[$archivo]}" ]; then
                    # Copiar el archivo al directorio correspondiente de la sucursal
                    cp "$archivo" "$temp_dir/$sucursal_num/"
                    archivos_copiados[$archivo]=1  # Marcar como copiado
                    echo "Archivo $tipo copiado para sucursal $sucursal_num: $archivo" | tee /dev/tty
                else
                    echo "Archivo ya copiado para la sucursal $sucursal_num: $archivo"
                fi
            else
                echo "Archivo no encontrado para el patrón: $patron"
            fi
        done
    done
done

echo -e "\nSe procesan los archivos para cada sucursal\n"
# Procesar cada sucursal 
for sucursal_dir in "$temp_dir"/*
do
    if [ -d "$sucursal_dir" ]; then
        numero_sucursal=$(basename "$sucursal_dir")
        
        # Se mandan los archivos a las sucursales usando SFTP
        if [ ${sucursales[$numero_sucursal]+_} ]; then
            dom=${sucursales[$numero_sucursal]}
            servidor_sftp="${dom}.tdfcard.com"
            
            echo -e "\nTransfiriendo archivos de la sucursal $numero_sucursal a $servidor_sftp\n"
            
            # Conectar a SFTP y transferir archivos
            sftp "$usuario_sftp@$servidor_sftp" <<EOF
cd $directorio_destino_sftp
$(for archivo in "$sucursal_dir"/*; do echo "put $archivo"; done)
bye
EOF
            echo -e "\nArchivos de la sucursal $numero_sucursal transferidos\n"

            echo -e "\n Los archivos en sucursal_dir:\n"
            for archivo in "$sucursal_dir"/*; do
                echo "Archivo: $archivo"
            done
            echo -e "\n Los archivos en $directorio_destino_sftp:\n"
            for archivo in "$directorio_destino_sftp"/*; do
                echo "Archivo: $archivo"
            done
            # Ejecutar cobranzas.sh siempre
            for archivo in "$sucursal_dir"/*; do
                nombre_archivo=$(basename "$archivo")
                fecha_archivo=$(echo "$nombre_archivo" | cut -d'-' -f4 | cut -d'.' -f1)

                if [[ "$nombre_archivo" == PAGDEB-TARJETAS-*-*.TXT ]]; then
                    echo -e "\nEjecutando script remoto cobranzas.sh para la sucursal $numero_sucursal, fecha $fecha_archivo\n"
                    if [ "$numero_sucursal" -eq 14 ]; then 
                        echo -e "\nSucursal $numero_sucursal se usa el usuario $usuario_remoto_suc14\n"

                        /usr/local/bin/tdfexec64 L "$servidor_sftp;" $usuario_remoto_suc14 $contrasena "cobranzas.sh $numero_sucursal $fecha_archivo"
                    else 
                        /usr/local/bin/tdfexec64 L "$servidor_sftp;" $usuario_remoto $contrasena "cobranzas.sh $numero_sucursal $fecha_archivo"

                    fi
                elif [[ "$nombre_archivo" == TRANSFERENCIAS-TARJETAS-*-*.TXT ]]; then
                    # Verificar si es después de las 17:30 para ejecutar transferencias.sh solo una vez
                    hora_actual=$(date +"%H%M")
                    if [ "$hora_actual" -ge 1730 ]; then
                        echo "Ejecutando script remoto transferencias.sh para la sucursal $numero_sucursal, fecha $fecha_archivo"

                        if [$numero_sucursal -eq 14 ]; then 
                            /usr/local/bin/tdfexec64 L "$servidor_sftp;" $usuario_remoto_suc14 $contrasena "transferencias.sh $numero_sucursal $fecha_archivo"
                        else 
                            /usr/local/bin/tdfexec64 L "$servidor_sftp;" $usuario_remoto $contrasena "transferencias.sh $numero_sucursal $fecha_archivo"
                        fi
                    else
                        echo "No es hora de ejecutar transferencias.sh. Se omite para la sucursal $numero_sucursal."
                    fi
                fi
                echo -e "\nProcesamiento completo para la sucursal $numero_sucursal\n"
                echo -e "\n Los archivos en $directorio_destino_sftp:\n"
                for archivo in "$directorio_destino_sftp"/*; do
                echo "Archivo: $archivo"
                done
            done
        else
            echo "No se encontró un dominio para la sucursal: $numero_sucursal"
        fi
    fi
done

# Limpiar el directorio temporal
rm -rf "$temp_dir"

echo -e "\nTodos los archivos han sido procesados.\n"

# Eliminar archivos de /public/Ariel/Rocio/archivosSuc 
#echo "Eliminando archivos en el directorio de destino: /public/Ariel/Rocio/archivosSuc..."
#rm -rf /public/Ariel/Rocio/archivosSuc/*
#echo "Archivos en /public/Ariel/Rocio/archivosSuc han sido eliminados."