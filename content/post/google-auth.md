+++
date = '2025-02-20'
title = '为 Nginx 添加 Google SSO 登录'
tags = ["linux", "nas"]
+++

<style>
.small img {
  max-width: 60% !important;
}
</style>

通过使用个人自建 NAS 取代云服务，我们能够获得对数据完全的控制和所有权。然而此时个人就要完全负担起数据的安全责任。许多 NAS 应用如云盘、相册等，默认仅使用用户名和密码进行认证，如果简单地暴露在公网上，可能并不能提供足够的安全性。[2FA](https://zh.wikipedia.org/wiki/%E5%A4%9A%E9%87%8D%E8%A6%81%E7%B4%A0%E9%A9%97%E8%AD%89)（双因素认证）是一种常见的安全认证机制，能够有效提高用户账户的安全性和可靠性。GitHub 目前[强制要求](https://github.blog/news-insights/company-news/software-security-starts-with-the-developer-securing-developer-accounts-with-2fa/)其所有用户启用 2FA，可见其对于账户安全保护的重要性。

<!-- more -->

并非所有的自部署服务都支持 2FA。对于不支持 2FA 的服务，接入可靠的第三方 SSO（单点登录）是一个比较好的选择。如果将服务接入 Google 的 OIDC 验证，那么用户必须要先登录 Google ，才能登录自部署的服务。这样服务就受到了等同于 Google 账号的 2FA 保护。同时 Google  SSO 还提供许多额外的好处，例如新登录的邮件提醒，无密码登录等。

![immich](./immich.png "immich 的登录页面，启用了 Google  OIDC 验证并关闭了密码登录")



并非所有自部署服务都提供了 2FA 支持。nginx 的 `ngx_http_auth_request_module` 模块提供了一个通用的方法，为 http 服务器接入任意的验证流程。[oauth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/) 就提供了将许多 OAuth2 提供商接入 nginx `auth_request` 流程的支持。将其与 nginx 配合，就可以对自部署服务提供 Google 登录的保护。

## 鉴权流程

在 nginx 中为 server 或 location 指定了 `auth_request` 服务器地址后，对该地址的访问请求将被全部转发到对应的 Auth 服务器。如果 Auth 服务器返回状态为 401 或 403，nginx 将停止正常处理请求，此时可以配置返回一个指向登录页面的重定向状态。当用户经过登录页面登录之后，Auth 服务器验证 nginx 传过来的 cookie，并返回 200 OK 状态，则 nginx 继续正常处理请求。下图分别展示了未登录请求和已登录请求的流程。

<div class="small">

![307](./nginx-auth-307.svg "未授权请求，返回 307 重定向到登录页面")

![200](./nginx-auth-200.svg "通过鉴权，正常访问上游资源")

</div>

下面介绍在 nginx 中接入 Google 登录的配置方法。

> 方便起见，我们假设服务部署在 mydomain.com 域名上。

## 配置 Google Auth Platform

首先需要进入 [Google Cloud Console](https://console.cloud.google.com) 创建一个新的项目。接下来在搜素框中搜索并进入 Google Auth Platform。在客户端界面创建一个 OAuth 客户端，类型选择「Web 应用」，并在「已获授权的重定向 URI」添加一个地址 `https://mydomain.com/oauth2/callback`。选择保存之后，可以在客户端列表中找到客户端 ID 和密钥。ID 和密钥将用于 oauth2-proxy 的配置。

## 配置 oauth2-proxy

使用 Docker Compose 可以方便地部署 oauth2-proxy。注意 oauth2-proxy 需要能够访问 Google，在国内需要配置代理环境变量 `https_proxy`。

```yaml
services:
  oauth2-proxy:
    image: quay.io/oauth2-proxy/oauth2-proxy
    container_name: oauth2-proxy
    command: --config /oauth2-proxy.cfg
    environment:
      - https_proxy=http://proxy-domain:1080
    volumes:
      - ./oauth2-proxy.cfg:/oauth2-proxy.cfg
    ports:
      - 4180:4180
    restart: unless-stopped
```

配置文件 `oauth2-proxy.cfg` 如下：

```toml
http_address="0.0.0.0:4180"
email_domains="gmail.com"
client_id="<客户端 ID>"
client_secret="<客户端密钥>"
# cookie secret 可使用 openssl rand -base64 32 | tr -- '+/' '-_' 生成
cookie_secret="..."

redirect_url="https://mydomain.com/oauth2/callback"
cookie_domains=".mydomain.com" # 这样使得 app1.mydomain.com 也可以实现登录
whitelist_domains=".mydomain.com"

reverse_proxy="true"
set_xauthrequest="true"
# 下面三行用于设置 Authorization
set_basic_auth="true"
basic_auth_password="sihpHj35wr"
prefer_email_to_user="true"
```

## 配置 nginx

接下来需要配置 nginx，配置文件如下。

```nginx
server {
    listen 443 ssl;
    server_name mydomain.com;

    ssl_certificate /etc/nginx/cert.pem;  # 指定SSL证书文件
    ssl_certificate_key /etc/nginx/key.pem;  # 指定SSL证书密钥文件

    # oauth2-proxy 的路径，无需 auth_request
    location /oauth2/ {
        proxy_pass http://127.0.0.1:4180;
        include /etc/nginx/snippets/http_proxy.conf;
        proxy_set_header X-Auth-Request-Redirect $request_uri;
    }

    # 其他路径收到 auth_request 保护
    location / {
        auth_request /oauth2/auth;
        error_page 401 = /oauth2/sign_in;

        auth_request_set $auth   $upstream_http_authorization;
        auth_request_set $user   $upstream_http_x_auth_request_user;
        auth_request_set $email  $upstream_http_x_auth_request_email;
        proxy_set_header Authorization        $auth;
        proxy_set_header X-Auth-Request-User  $user;
        proxy_set_header X-Auth-Request-Email $email;

        # if you enabled --cookie-refresh, this is needed for it to work with auth_request
        auth_request_set $auth_cookie $upstream_http_set_cookie;
        add_header Set-Cookie $auth_cookie;

        proxy_pass http://localhost:82;
        include /etc/nginx/snippets/http_proxy.conf;
    }
}

# OAuth2 验证后必须经过这层验证
server {
    listen 82;
    server_name _;

    auth_basic "Restricted Area";
    auth_basic_user_file /etc/nginx/.google_passwd;
    error_page 401 = @forbbiden;

    location / {
        proxy_pass http://localhost:80;
        include /etc/nginx/snippets/http_proxy.conf;
    }

    location @forbbiden {
        return 403;
    }
}

# 实际的 HTTP 服务
server {
    listen 80;
    server_name _;

    location / {
        # ...
    }
}
```

在上面的配置中，使用了 `auth_request` 将鉴权请求发送到 oauth2_proxy。oauth2_proxy 在验证成功后，会添加 X-Auth-Request-User，X-Auth-Request-Email 两个 header，分别代表登录的用户和邮箱，同时会根据上面配置文件中设置的硬编码密码生成 [HTTP Basic Auth](https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Authentication#basic_%E9%AA%8C%E8%AF%81%E6%96%B9%E6%A1%88) 的 header，并转发到 82 端口。

直到这个时候，任何登录了 Google 账号的第三方用户都可以通过 oauth2_proxy 的验证，让请求进入到 82 端口。oauth2_proxy 实际上只起到了**认证**（Authentication）的作用，也就是确保 HTTP 请求确实是来自 X-Auth-Request-Email 所标示的邮箱持有者。而**授权**（Authorization）则由 HTTP Basic Auth 配合后面的 82 端口服务解决。

82 端口是另一个反向代理，用来保证只有允许的用户能够正常访问资源。passwd 文件通过下面的命令创建：

```shell
printf sihpHj35wr | sudo htpasswd -cBi /etc/nginx/.google_passwd user1@gmail.com
printf sihpHj35wr | sudo htpasswd -Bi /etc/nginx/.google_passwd user2@gmail.com
...
```

`sihpHj35wr` 是之前在 `oauth2-proxy.cfg` 里面设置的 Basic Auth 密码，仅作为占位使用。未经授权的用户 Google 登录后访问网站，将无法通过 82 端口服务器的验证而得到 403。至此便完成了 Google SSO 登录的配置。

## 其他 OAuth2 提供方

oauth2-proxy 不仅支持 Google，还支持[许多其他](https://oauth2-proxy.github.io/oauth2-proxy/configuration/providers/)的 OAuth2 提供方。在实验室或者小团队搭建的服务器中，GitLab 提供的 OAuth2 SSO 登录也许是一个更好的选择。此时由于 GitLab 账户是面向团队内部创建的，所以 oauth2-proxy 可以同时承担认证和授权的工作，无需再配置一个用于授权的反向代理。

[Authentik](https://goauthentik.io/) 是另一个更灵活和功能丰富的选择。它是专门的用户管理服务，可以进行 2FA，权限分组等设置。Authentik 自身就可以替代 oauth2-proxy，作为 nginx 的 `auth_request` 上游。

