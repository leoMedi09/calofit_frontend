import requests
import re
import json

# Configuración simplificada
BASE_URL = "http://localhost:8000"
ENDPOINT = f"{BASE_URL}/asistente/consultar"

print("--- START TEST ---")

payload = {"usuario_id": 1, "mensaje": "Dame una receta de Quinua con Verduras"}
try:
    print(f"Enviando peticion a {ENDPOINT}...")
    r = requests.post(ENDPOINT, json=payload, timeout=30)
    print(f"Status Code: {r.status_code}")
    
    if r.status_code == 200:
        data = r.json()
        secciones = data.get('respuesta_estructurada', {}).get('secciones', [])
        for s in secciones:
            if s.get('tipo') == 'comida':
                nombre = s.get('nombre')
                macros = s.get('macros')
                print(f"PLATO: {nombre}")
                print(f"MACROS: {macros}")
                
                # Auditoría rápida
                p = float(re.search(r'P:\s*(\d+)', macros).group(1))
                c = float(re.search(r'C:\s*(\d+)', macros).group(1))
                g = float(re.search(r'G:\s*(\d+)', macros).group(1))
                cal_decl = float(re.search(r'Cal:\s*(\d+)', macros).group(1))
                cal_calc = (p*4) + (c*4) + (g*9)
                print(f"CALC: {cal_calc} | DECLARE: {cal_decl}")
                print(f"DIFERENCIA: {abs(cal_calc - cal_decl)}")
    else:
        print(f"Error: {r.text}")
except Exception as e:
    print(f"EXCEPCION: {e}")

print("--- END TEST ---")
