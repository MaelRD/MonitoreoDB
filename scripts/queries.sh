#!/bin/bash

# ============================================
# Consultas Útiles PostgREST
# ============================================

API_URL="http://localhost:3000"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_menu() {
  echo ""
  echo "========================================="
  echo "   CONSULTAS DISPONIBLES"
  echo "========================================="
  echo "1. Listar empleados"
  echo "2. Listar departamentos"
  echo "3. KPI mensual por departamento"
  echo "4. Consumo empleados"
  echo "5. Top apps por categoría"
  echo "6. Alertas no resueltas"
  echo "7. Apps productivas"
  echo "8. Apps distractoras"
  echo "9. Accesos del día"
  echo "0. Salir"
  echo "========================================="
}

query_empleados() {
  echo -e "${YELLOW}📋 Listando empleados...${NC}"
  curl -s "$API_URL/empleados?select=nombre,email,departamentos(nombre),estado" | jq .
}

query_departamentos() {
  echo -e "${YELLOW}🏢 Listando departamentos...${NC}"
  curl -s "$API_URL/departamentos" | jq .
}

query_kpi_mensual() {
  echo -e "${YELLOW}📊 KPI mensual...${NC}"
  curl -s "$API_URL/v_kpi_mensual_actual" | jq .
}

query_consumo_empleados() {
  echo -e "${YELLOW}⏱️  Consumo empleados...${NC}"
  curl -s "$API_URL/v_empleado_consumo?order=porcentaje_productivo.desc" | jq .
}

query_top_apps() {
  echo -e "${YELLOW}🏆 Top apps por categoría...${NC}"
  curl -s "$API_URL/v_top_apps_por_categoria?order=posicion.asc" | jq .
}

query_alertas() {
  echo -e "${YELLOW}⚠️  Alertas no resueltas...${NC}"
  curl -s "$API_URL/alertas?resuelta=eq.false&order=fecha_alerta.desc" | jq .
}

query_apps_productivas() {
  echo -e "${YELLOW}✅ Apps productivas...${NC}"
  curl -s "$API_URL/aplicaciones?categoria_id=eq.1&order=nombre_app.asc" | jq '.[] | {nombre_app, dominio}'
}

query_apps_distractoras() {
  echo -e "${YELLOW}❌ Apps distractoras...${NC}"
  curl -s "$API_URL/aplicaciones?categoria_id=eq.2&order=nombre_app.asc" | jq '.[] | {nombre_app, dominio}'
}

query_accesos_hoy() {
  echo -e "${YELLOW}📱 Accesos del día...${NC}"
  FECHA=$(date +%Y-%m-%d)
  curl -s "$API_URL/accesos_diarios?fecha=eq.$FECHA&select=empleados(nombre),aplicaciones(nombre_app),minutos_totales&order=minutos_totales.desc" | jq .
}

while true; do
  show_menu
  read -p "Selecciona opción: " option

  case $option in
    1) query_empleados ;;
    2) query_departamentos ;;
    3) query_kpi_mensual ;;
    4) query_consumo_empleados ;;
    5) query_top_apps ;;
    6) query_alertas ;;
    7) query_apps_productivas ;;
    8) query_apps_distractoras ;;
    9) query_accesos_hoy ;;
    0) echo "👋 Hasta luego"; exit 0 ;;
    *) echo -e "${RED}Opción inválida${NC}" ;;
  esac

  read -p "Presiona ENTER para continuar..."
done
