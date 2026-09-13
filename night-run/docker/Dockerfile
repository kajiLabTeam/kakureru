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

# Claude Code CLI(npm配布パッケージ。ホスト側の native installer版と同一ソース)。
# バージョンを固定する。固定しないとビルドした時点のlatestで固まり、ビルドの
# タイミングによってホスト側のCLIと無言でバージョンがずれる(2026-09-13の実運用で
# host 2.1.270 / container 2.1.197という差異を確認済み)。上げるときはここを変える。
ARG CLAUDE_CODE_VERSION=2.1.270
RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}"

# Flutter SDK。Android SDKは意図的にインストールしない
# (このシステムが自律実行するのは flutter test/analyze/build_runner までで、
#  実機/エミュレータが要る `flutter run` や `flutter build apk` は対象外のため)
RUN git clone --branch "$FLUTTER_VERSION" --depth 1 https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
# claude -pは実際には非rootの'runner'ユーザーで動く(entrypoint.sh参照)。
# CIでの非対話実行を前提にする(analyticsやウェルカムメッセージ等の
# 初回プロンプトを抑止する。$HOMEが違う任意のユーザーで動かす前提とも噛み合う)。
ENV CI=true
RUN flutter config --no-analytics && flutter precache

RUN useradd -m -s /bin/bash runner
# /opt/flutterはこの時点までrunnerユーザー作成前のrootが所有したまま。
# 2026-09-13の実運用で以下の2つの不具合を確認済み:
#   1. runnerがbin/cache配下に書き込めない(Permission denied)
#   2. flutterが内部で使うgitが、実行ユーザー(runner)と所有者(root)の
#      不一致を「dubious ownership」として拒否し、flutter --versionすら
#      失敗する(タスク実行中のエージェントが混乱し、$HOME配下に別の
#      flutterを再インストールしようとして時間を浪費する原因になった)。
# 所有者をrunnerに揃えることで両方解消する。
RUN chown -R runner:runner /opt/flutter

# サンドボックスマーカー(0.2節)。イメージに焼き込まれるためホスト側で偽装できない。
ENV NIGHT_RUNNER_SANDBOX=1
RUN touch /.sandbox-marker

COPY init-firewall.sh /usr/local/bin/init-firewall.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/init-firewall.sh /usr/local/bin/entrypoint.sh

WORKDIR /workdir
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
