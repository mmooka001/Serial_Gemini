import serial
import time

def run_monitor():
    try:
        # 尝试打开 COM2
        ser = serial.Serial('COM2', 115200, timeout=1)
        print(f"--- Listening on {ser.name} ---")
        
        while True:
            if ser.in_waiting > 0:
                # 读取所有可用字节
                data = ser.read(ser.in_waiting)
                # 打印原始字节的十六进制
                hex_data = ' '.join([f"{b:02X}" for b in data])
                print(f"[{time.strftime('%H:%M:%S')}] RECV: {hex_data}")
                
                # 回显数据
                ser.write(data)
                print(f"[{time.strftime('%H:%M:%S')}] ECHO: {hex_data}")
            time.sleep(0.1)
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    run_monitor()
