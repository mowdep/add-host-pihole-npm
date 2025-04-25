# Pi-hole CNAME and Nginx Proxy Manager Automation

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A bash utility script to automate two common tasks in a homelab or self-hosted environment:

1. Creating CNAME DNS records in Pi-hole
2. Configuring proxy hosts in Nginx Proxy Manager

Built with a focus on simplicity, good error handling, and clear feedback with color-coded emoji output.

## 🚀 Features

- **Automated Configuration**: Set up both DNS records and proxy configurations in one command
- **Selective Operations**: Run only the DNS or proxy part if needed
- **Force Mode**: Overwrite existing entries when necessary
- **Debug Mode**: Detailed output for troubleshooting
- **Error Handling**: Comprehensive error checking with helpful messages
- **Beautiful Output**: Color-coded emoji feedback for clear status visibility

## 📋 Requirements

- Pi-hole with REST API access
- Nginx Proxy Manager instance
- `curl` and `jq` installed on your system

## ⚙️ Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/mowdep/pihole-npm-automation.git
   cd pihole-npm-automation
   ```

2. Make the script executable:
   ```bash
   chmod +x add_app.sh
   ```

3. Edit the script to update your environment configuration:
   ```bash
   nano add_app.sh
   ```
   
   Update these values at the top of the script:
   ```bash
   PIHOLE_URL="https://your-pihole-url"
   NPM_URL="https://your-npm-url"
   DOMAIN_SUFFIX="yourdomain.com"
   CERT_ID=2  # Your SSL certificate ID from NPM
   NPM_EMAIL="your-npm-email@example.com"
   NPM_PASSWORD="your-npm-password"
   ```

## 🔧 Usage

### Basic Usage

Set up both DNS and proxy:
```bash
./add_app.sh --dest myapp --source 192.168.1.50:8080
```

This will:
1. Create a CNAME record `myapp.yourdomain.com` pointing to `proxy.yourdomain.com` in Pi-hole
2. Configure Nginx Proxy Manager to proxy requests to `192.168.1.50:8080` with HTTPS enabled

### Only Add DNS Record

```bash
./add_app.sh --dest myapp --cname-only
```

### Only Add Proxy Configuration

```bash
./add_app.sh --dest myapp --source 192.168.1.50:8080 --proxy-only
```

### Force Overwrite Existing Entries

```bash
./add_app.sh --dest myapp --source 192.168.1.50:8080 --force
```

### Debug Mode

```bash
./add_app.sh --dest myapp --source 192.168.1.50:8080 --debug
```

### Help

```bash
./add_app.sh --help
```

## 📊 Example Output

```
ℹ️  🚀 Starting configuration for myapp.yourdomain.com
ℹ️  🔌 Backend service: 192.168.1.50:8080
ℹ️  Adding CNAME record to Pi-hole: myapp.yourdomain.com → proxy.yourdomain.com
✅ CNAME record added successfully
ℹ️  Configuring Nginx Proxy Manager for myapp.yourdomain.com
✅ Proxy host configured successfully with HTTPS (ID: 42)

✅ Configuration complete! 🎉
📋 Summary:
  • Domain: myapp.yourdomain.com
  • CNAME points to: proxy.yourdomain.com
  • Backend service: 192.168.1.50:8080
  • HTTPS: ✅ (Certificate ID: 2)

🌐 Your service should be accessible at: https://myapp.yourdomain.com
```

## 🔍 Troubleshooting

If you encounter issues:

1. Run the script with `--debug` flag for detailed output
2. Make sure Pi-hole and NPM are accessible and properly configured
3. Verify your NPM credentials are correct
4. Check the certificate ID exists in your NPM instance

Common errors:
- `400 Bad Request`: The NPM API payload may need adjustments for your version
- Authentication failures: Check your credentials

## 🔒 Security Notes

- This script contains credential information for your Nginx Proxy Manager
- Consider using environment variables instead of hardcoding credentials
- Make sure your Pi-hole API is properly secured

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- The Pi-hole team for their amazing DNS solution
- The Nginx Proxy Manager project
- Everyone who contributes to open-source software

---

Created by [mowdep](https://github.com/mowdep) | Last updated: 2025-04-25
