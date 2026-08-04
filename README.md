# Chirpy POS

Chirpy POS is an offline-first point-of-sale system for Windows and Android. Every sale is committed to local SQLite first; connected devices synchronize through the Laravel API. A client never connects to MySQL directly.

## Included foundation

- Flutter client source with a responsive cashier workspace, SQLite sales storage, and a durable sync queue.
- Laravel 12 API with token authentication, device enrollment, multi-business data isolation, product access, audit records, and idempotent sale synchronization.
- MySQL schema for products, multiple barcodes, inventory, sales, payments, stock movements, branches, devices, sync operations, and audit logs.
- Docker production deployment: PHP-FPM API, Nginx, and MySQL with persistent named volumes and health-gated startup.

## Inventory flow

1. Create products with a unit and reorder level, then assign them to the appropriate branch.
2. Receive deliveries through `POST /api/inventory/receive`; on-hand stock rises and a `receive` movement is written.
3. Use `POST /api/inventory/adjust` only for counted corrections, damage, expiry, and returns. The reason and note are retained.
4. Move stock with `POST /api/inventory/transfer`. The source is decremented and destination incremented inside one database transaction.
5. Run a physical count with `POST /api/inventory/count`; the difference is recorded as a `stock_count` movement rather than silently replacing a quantity.
6. Read the on-hand list, ledger, and replenishment list from `GET /api/inventory`, `/api/inventory/movements`, and `/api/inventory/low-stock`.

All inventory actions are restricted to management or inventory roles, write audit records, and can be submitted later through the offline sync queue. Negative stock is rejected unless that product explicitly permits it.

## Production deployment

1. Copy `.env.deploy.example` to `.env.deploy`. Set unique database passwords, `APP_URL`, and `APP_KEY`. Generate a key with `docker compose run --rm api php artisan key:generate --show` before the first `up`.
2. Start the stack with `docker compose --env-file .env.deploy up -d --build`.
3. Create the first owner from the API container:

   ```sh
   docker compose exec api php artisan pos:owner "Store Name" "Owner Name" owner@example.com
   ```

4. Put a TLS reverse proxy such as Caddy, Traefik, or your cloud load balancer in front of port `8080`; expose only HTTPS publicly. Keep MySQL private to the Docker network.
5. Back up the `mysql_data` volume daily and test restoring it before go-live.

The API health check is `GET /api/health`. Public registration is off by default; staff accounts should be created through an authenticated management workflow, not a public endpoint.

## Local development

The existing `server/.env` uses SQLite solely for local tests. For a local shared server, configure MySQL values in `server/.env`, run `php artisan migrate`, then run `php artisan serve --host=0.0.0.0 --port=8000` from `server/`.

After installing Flutter, generate any missing platform wrappers and run the client from `client/`:

```sh
flutter create --org com.chirpy --project-name chirpy_pos .
flutter pub get
flutter run -d windows
```

For Android, choose a connected Android device instead. Before a production store launch, validate the specific printer, scanner, cash drawer, weighing scale, card terminal, and e-wallet provider that the business will actually use; those integrations are vendor-specific and cannot be safely guessed.
