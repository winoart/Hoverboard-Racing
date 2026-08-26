import os
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

class S(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        
        try:
            scripts = json.loads(post_data.decode('utf-8'))
            for script_info in scripts:
                # Path comes like "ServerScriptService/Script"
                path_parts = script_info['path'].split('/')
                service = path_parts[0]
                
                # We map services to Rojo src folders
                # e.g., ServerScriptService -> src/server
                # StarterPlayer/StarterPlayerScripts -> src/client
                # ReplicatedStorage -> src/shared
                
                base_dir = "src"
                if service == "ServerScriptService" or service == "ServerStorage":
                    base_dir = "src/server"
                elif service == "StarterPlayer" or service == "StarterGui" or service == "StarterPack":
                    base_dir = "src/client"
                elif service == "ReplicatedStorage":
                    base_dir = "src/shared"
                
                # Build the file path
                file_name = path_parts[-1]
                if script_info['className'] == 'Script':
                    file_name += ".server.lua"
                elif script_info['className'] == 'LocalScript':
                    file_name += ".client.lua"
                else:
                    file_name += ".lua"
                
                # Create subdirectories if needed (ignoring the first service name in path)
                sub_path = "/".join(path_parts[1:-1])
                full_dir = os.path.join(base_dir, sub_path)
                os.makedirs(full_dir, exist_ok=True)
                
                full_path = os.path.join(full_dir, file_name)
                with open(full_path, 'w', encoding='utf-8') as f:
                    f.write(script_info['source'])
                    
            print(f"Successfully extracted {len(scripts)} scripts!")
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'OK')
            
            # Stop the server after receiving data once
            raise KeyboardInterrupt
            
        except Exception as e:
            print("Error:", e)
            self.send_response(500)
            self.end_headers()

if __name__ == '__main__':
    server = HTTPServer(('localhost', 8080), S)
    print("Listening on 8080... Waiting for Studio to send data.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    print("Server stopped.")
