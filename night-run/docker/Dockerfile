# 夜間自律タスク実行用の使い捨てサンドボックスイメージ(docs/night-run-design.md 0章)。
# ビルド時はネットワーク制限なし(ツールのインストールに必要)。
# 実行時のネットワーク制限は entrypoint.sh 経由の init-firewall.sh が担う。
FROM node:20-bookworm-slim

# .metadata / ローカル `flutter --version` と一致させること。Flutterを上げるときはここを変える。
ARG FLUTTER_VERSION=3.44.8

RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl unzip xz-utils ca-certificates python3 \
        iptables ipset dnsutils jq \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI(公式apt repo)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Claude Code CLI(npm配布パッケージ。ホスト側の native installer版と同一ソース)
RUN npm install -g @anthropic-ai/claude-code

# Flutter SDK。Android SDKは意図的にインストールしない
# (このシステムが自律実行するのは flutter test/analyze/build_runner までで、
#  実機/エミュレータが要る `flutter run` や `flutter build apk` は対象外のため)
RUN git clone --branch "$FLUTTER_VERSION" --depth 1 https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
RUN flutter config --no-analytics && flutter precache

RUN useradd -m -s /bin/bash runner

# サンドボックスマーカー(0.2節)。イメージに焼き込まれるためホスト側で偽装できない。
ENV NIGHT_RUNNER_SANDBOX=1
RUN touch /.sandbox-marker

COPY init-firewall.sh /usr/local/bin/init-firewall.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/init-firewall.sh /usr/local/bin/entrypoint.sh

WORKDIR /workdir
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
