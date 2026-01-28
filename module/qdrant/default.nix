{ config, pkgs, lib, ... }:
{
  # Enable Qdrant service
  services.qdrant = {
    enable = true;
    
    settings = {
      # Storage configuration
      storage = {
        # Store data in /var/lib/qdrant (default systemd StateDirectory)
        storage_path = "/var/lib/qdrant/storage";
        snapshots_path = "/var/lib/qdrant/snapshots";
        
        # Store payloads on disk to save RAM
        # Recommended for local development
        on_disk_payload = true;
        
        # Performance settings
        performance = {
          # Auto-detect available CPU cores
          max_search_threads = 0;
        };
      };
      
      # Service configuration
      service = {
        # HTTP REST API
        http_port = 6333;
        
        # gRPC API (higher performance)
        grpc_port = 6334;
        
        # Bind to localhost only (security)
        # Change to "0.0.0.0" only if remote access needed
        host = "127.0.0.1";
        
        # Maximum request size (32MB default)
        max_request_size_mb = 32;
        
        # CORS disabled for local use
        # Enable if accessing from web browser apps
        enable_cors = false;
        
        # TLS disabled for local development
        enable_tls = false;
      };
      
      # Cluster mode (disabled for single-node local setup)
      cluster = {
        enabled = false;
      };
      
      # Logging configuration
      log_level = "INFO";  # Options: TRACE, DEBUG, INFO, WARN, ERROR
    };
  };
  
  # Note: Firewall is NOT opened by default (local-only access)
  # To enable remote access, uncomment these lines:
  # networking.firewall.allowedTCPPorts = [ 6333 6334 ];
  
  # Optional: Add qdrant CLI tools to system packages
  # environment.systemPackages = with pkgs; [
  #   qdrant  # Includes qdrant binary for CLI operations
  # ];
}
