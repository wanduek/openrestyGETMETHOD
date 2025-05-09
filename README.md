# openresty 학습 레포
===================


- DB: POSTGRESQL, Redis
## VERSION: 
- openresty:latest
- postgreSQL: 14,
- Redis: 7

## Library:
- lua-resty-jwt
- lua-resty-json

## API

### api/v1/signin

| Method | Request                                                                | Response Body                                                      |
|--------|--------------------------------------------------------------------------------------|--------------------------------------------------------------------|
| POST   | - `email`: VARCHAR(100)  <br> - `password`: VARCHAR(100) | - `token`: JWT payload <br> - `message`: `"Signin successful"` |

### api/v1/signup

| Method | Request                                                                | Response Body                                                      |
|--------|--------------------------------------------------------------------------------------|--------------------------------------------------------------------|
| POST   | - `email`: VARCHAR(100)  <br> - `password`: VARCHAR(100)  <br> - `role`: VARCHAR(100)  <br> - `type`: VARCHAR(100)  <br> - `nickname`: VARCHAR(255) | - `token`: JWT payload <br> - `message`: `"User registered successfully"` |


### api/v1/channels/post

| Method | Request                                                                | Response Body                                                      |
|--------|--------------------------------------------------------------------------------------|--------------------------------------------------------------------|
| POST   | - `name`: VARCHAR(100)  <br> - `base_currency`: VARCHAR(100) | - `token`: JWT payload <br> - `message`: `"Channel created successfully"` <br> - `channel_id`: `Integer` |

### api/v1/channels/join

| Method | Request                                                                | Response Body                                                      |
|--------|--------------------------------------------------------------------------------------|--------------------------------------------------------------------|
| POST   | - `channel_id`: Integer | - `token`: JWT payload <br> - `message`: `"Channel created successfully"` <br> - `channel_id`: `Integer` |

### api/v1/papp 

| Method | Request                                                                | Response Body                                                      |
|--------|--------------------------------------------------------------------------------------|--------------------------------------------------------------------|
| POST   | - `p_app_code`: VARCHAR(50) <br> -`granted_abilities`: VARCHAR(50) | - `token`: JWT payload <br> - `message`: `"pApps created successfully"` <br> - `channel_id`: Integer <br> - `pAppCode`: "B00004" <br> - `grantedAbilities`: "POST" |

### api/v1/profile

| Method | Request                                                                | Response Body                                                      |
|--------|--------------------------------------------------------------------------------------|--------------------------------------------------------------------|
| POST   | - `age`: VARCHAR(50) <br> -`birth_year`: VARCHAR(50) <br> - `certified_age`: VARCHAR(50) <br> - `gender`: VARCHAR(50) <br> - `image_src`: VARCHAR(255) <br> - `is_featured`: BOOLEAN <br> - `nickname`: VARCHAR(255)| - `token`: JWT payload <br> - `message`: `"profile created successfully"` <br> - `channel_id`: Integer <br> - `profile_id`: Integer|


### seller/api/v1/records

| Method | HEADER           | Request                                                                | Response Body                                                      |
|--------|------------------|--------------------------------------------------------------------------------------|--------------------------------------------------------------------|
| GET   | `X-Channel-Id`: STRING | | - `token`: JWT payload <br> - `message`: `"profile created successfully"` <br> - `channel_id`: Integer <br> - `profile_id`: Integer|