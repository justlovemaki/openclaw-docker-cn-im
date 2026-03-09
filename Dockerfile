# OpenClaw Docker 镜像
FROM node:22-slim

# 设置工作目录
WORKDIR /app

# 设置环境变量
ENV BUN_INSTALL="/usr/local" \
    PATH="/usr/local/bin:$PATH" \
    DEBIAN_FRONTEND=noninteractive

# 1. 合并系统依赖安装与全局工具安装，并清理缓存
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    chromium \
    curl \
    build-essential \
    fonts-liberation \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
    git \
    gosu \
    jq \
    openssh-client \
    procps \
    python3 \
    socat \
    tini \
    unzip \
    websockify && \
    # 配置 git 使用 HTTPS 替代 SSH
    git config --system url."https://github.com/".insteadOf ssh://git@github.com/ && \
    # 更新 npm 并安装全局包
    npm install -g npm@latest && \
    npm install -g openclaw@2026.3.8 opencode-ai@latest playwright playwright-extra puppeteer-extra-plugin-stealth @steipete/bird && \
    # 安装飞书官方插件 CLI
    curl -fsSL https://sf3-cn.feishucdn.com/obj/open-platform-opendoc/4d184b1ba733bae2423a89e196a2ef8f_QATOjKH1WN.tgz -o /tmp/feishu-openclaw-plugin-onboard-cli.tgz && \
    npm install -g /tmp/feishu-openclaw-plugin-onboard-cli.tgz && \
    # 安装 bun 和 qmd
    curl -fsSL https://bun.sh/install | BUN_INSTALL=/usr/local bash && \
    /usr/local/bin/bun install -g @tobilu/qmd && \
    # 安装 Playwright 浏览器依赖
    npx playwright install chromium --with-deps && \
    # 清理 apt 缓存
    apt-get purge -y --auto-remove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /root/.npm /root/.cache

# 2. 插件安装（作为 node 用户以避免后期权限修复带来的镜像膨胀）
RUN mkdir -p /home/node/.openclaw/workspace /home/node/.openclaw/extensions && \
    chown -R node:node /home/node

USER node
ENV HOME=/home/node
WORKDIR /home/node

RUN cd /home/node/.openclaw/extensions && \
  git clone --depth 1 https://github.com/soimy/openclaw-channel-dingtalk.git dingtalk && \
  cd dingtalk && \
  npm install --omit=dev --legacy-peer-deps && \
  timeout 300 openclaw plugins install -l . || true && \
  cd /home/node/.openclaw/extensions && \
  git clone --depth 1 -b v4.17.25 https://github.com/Daiyimo/openclaw-napcat.git napcat && \
  cd napcat && \
  npm install --production && \
  timeout 300 openclaw plugins install -l . || true && \
  cd /home/node/.openclaw && \
  git clone --depth 1 https://github.com/justlovemaki/qqbot.git && \
  cd qqbot && \
  timeout 300 openclaw plugins install . || true && \
  timeout 300 openclaw plugins install @sunnoy/wecom || true && \
  # 预执行安装命令（容器内需手动交互，此处仅作声明或环境准备）
  # feishu-plugin-onboard install && \
  find /home/node/.openclaw/extensions -name ".git" -type d -exec rm -rf {} + && \
  rm -rf /home/node/.openclaw/qqbot/.git && \
  rm -rf /tmp/* /home/node/.npm /home/node/.cache
  
# 3. 最终配置
USER root

# 复制初始化脚本并确保换行符为 LF
COPY ./init.sh /usr/local/bin/init.sh
RUN sed -i 's/\r$//' /usr/local/bin/init.sh && \
    chmod +x /usr/local/bin/init.sh

# 设置环境变量
ENV HOME=/home/node \
    TERM=xterm-256color \
    NODE_PATH=/usr/local/lib/node_modules

# 暴露端口
EXPOSE 18789 18790

# 设置工作目录为 home
WORKDIR /home/node

# 使用初始化脚本作为入口点
ENTRYPOINT ["/bin/bash", "/usr/local/bin/init.sh"]
