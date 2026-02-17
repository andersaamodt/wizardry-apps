# Signing Secrets

All signing credentials must be stored as GitHub encrypted secrets in protected environments.
Tag-triggered release jobs are configured to fail when required signing secrets are missing.

## Apple

- `APPLE_P12_BASE64`
- `APPLE_P12_PASSWORD`
- `APPLE_TEAM_ID`
- `APPLE_DEVELOPER_ID_APP`
- `APPLE_NOTARY_KEY_ID`
- `APPLE_NOTARY_ISSUER_ID`
- `APPLE_NOTARY_PRIVATE_KEY_BASE64`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY_BASE64`

`promote-stores.yml` iOS automation uses the three `APP_STORE_CONNECT_*` secrets.

## Android

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `PLAY_SERVICE_ACCOUNT_JSON_BASE64`

## Hosted Web Deploy

- `WEB_DEPLOY_SSH_KEY_BASE64`
- `WEB_DEPLOY_HOST`
- `WEB_DEPLOY_USER`
- `WEB_DEPLOY_PATH`

No secrets may be committed to the repository.
