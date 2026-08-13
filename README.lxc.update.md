
### Added automation for A, B, C and LXC 103 (hermes-ai)

Saya menambahkan skrip-skrip berikut:

- scripts/auto-install-origin-cert.sh  — menyalin Cloudflare Origin Cert ke LXC (100) dan melakukan langkah-langkah dasar untuk menghubungkannya ke vhost OpenLiteSpeed.
- scripts/wp-auto-install.sh           — menyelesaikan instalasi WordPress menggunakan wp-cli di LXC 100.
- scripts/deploy-node-service.sh      — helper untuk menjalankan aplikasi Node.js dengan pm2 di LXC 101 dan mengatur startup.
- scripts/create-lxc-hermes-ai.sh     — membuat LXC 103 dan meng-deploy LocalAI via Docker; pengguna harus menaruh model ggml di /opt/localai/models.

Catatan ringkas tentang Hermès-AI (LXC 103):
- Saya memilih LocalAI sebagai server inference karena:
  - Open-source dan gratis.
  - Menyediakan API yang kompatibel OpenAI.
  - Dapat menjalankan berbagai model ggml (pilih yang kecil ~<2GB untuk RAM 4GB).
- Model rekomendasi ringan: gpt4all (quantized) ~800MB atau model ggml kecil lainnya dari HuggingFace.
- Untuk gambar: LocalAI fokus teks; untuk generasi gambar lokal Anda memerlukan SD webui atau server lain (berat). Alternatif: gunakan layanan cloud yang gratis/low-cost untuk image generation.

Lihat README.lxc.md untuk instruksi ringkas.
