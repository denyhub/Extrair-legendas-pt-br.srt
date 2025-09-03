#!/bin/bash
# Script simples e funcional para extrair legendas

DIR="${1:-$(pwd)}"
echo "🎬 Extraindo legendas de: $DIR"
echo "📅 Início: $(date)"

# Contadores
PROCESSADOS=0
SUCESSOS=0
ERROS=0

# Processa cada arquivo MKV
for arquivo in "$DIR"/*.mkv; do
    # Verifica se o arquivo existe (caso não haja arquivos MKV)
    [ ! -f "$arquivo" ] && continue
    
    nome_base="${arquivo%.mkv}"
    srt_file="${nome_base}.srt"
    nome_arquivo=$(basename "$arquivo")
    
    PROCESSADOS=$((PROCESSADOS + 1))
    
    echo ""
    echo "🔄 [$PROCESSADOS] Processando: $nome_arquivo"
    
    # Verifica se já existe SRT
    if [ -f "$srt_file" ]; then
        echo "⏭️  Já existe SRT, pulando..."
        continue
    fi
    
    # Mostra as faixas de legenda disponíveis
    echo "📋 Analisando faixas de legenda..."
    
    # Cria arquivo temporário para as informações
    temp_info=$(mktemp)
    
    # Obtém informações das faixas de legenda
    ffprobe -v quiet -select_streams s -show_entries stream=index,codec_name:stream_tags=language,title -of csv=p=0 "$arquivo" 2>/dev/null > "$temp_info"
    
    if [ ! -s "$temp_info" ]; then
        echo "❌ Nenhuma faixa de legenda encontrada"
        rm -f "$temp_info"
        ERROS=$((ERROS + 1))
        continue
    fi
    
    # Mostra as faixas encontradas
    echo "📝 Faixas disponíveis:"
    counter=0
    while IFS=',' read -r idx codec lang title; do
        echo "     $counter: $codec, $lang, $title"
        counter=$((counter + 1))
    done < "$temp_info"
    
    rm -f "$temp_info"
    
    # Tenta extrair legendas em ordem de prioridade
    # Baseado no seu sucesso anterior, sabemos que faixa 6 é português brasileiro
    TENTATIVAS=(6 10 9 8 7 5 4 3 2 1 0)
    EXTRAIU=false
    
    for faixa in "${TENTATIVAS[@]}"; do
        echo "🔄 Tentando extrair faixa $faixa..."
        
        # Tenta extrair
        if ffmpeg -i "$arquivo" -map "0:s:$faixa?" -c:s srt "$srt_file" -y -loglevel error 2>/dev/null; then
            # Verifica se o arquivo foi criado e não está vazio
            if [ -s "$srt_file" ]; then
                echo "✅ Sucesso! Legenda extraída da faixa $faixa"
                
                # Mostra uma amostra da legenda
                echo "📝 Amostra da legenda:"
                head -20 "$srt_file" | grep -v "^[0-9]*$" | grep -v "^[0-9][0-9]:[0-9][0-9]" | head -3 | sed 's/^/    /'
                
                SUCESSOS=$((SUCESSOS + 1))
                EXTRAIU=true
                break
            else
                # Remove arquivo vazio
                rm -f "$srt_file" 2>/dev/null
            fi
        fi
    done
    
    if [ "$EXTRAIU" = false ]; then
        echo "❌ Falha: Não foi possível extrair legenda"
        ERROS=$((ERROS + 1))
    fi
    
    echo "---"
done

# Estatísticas finais
echo ""
echo "🏁 Processamento concluído!"
echo "📊 Estatísticas:"
echo "   • Arquivos processados: $PROCESSADOS"
echo "   • Sucessos: $SUCESSOS"
echo "   • Erros: $ERROS"

# Contagem de arquivos
TOTAL_MKV=$(ls -1 "$DIR"/*.mkv 2>/dev/null | wc -l)
TOTAL_SRT=$(ls -1 "$DIR"/*.srt 2>/dev/null | wc -l)

echo "📁 Arquivos na pasta:"
echo "   • Total MKV: $TOTAL_MKV"
echo "   • Total SRT: $TOTAL_SRT"
echo "   • Taxa de conversão: $(( TOTAL_SRT * 100 / TOTAL_MKV ))%"

echo "📅 Fim: $(date)"
