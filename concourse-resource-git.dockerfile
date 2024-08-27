FROM alpine:3 AS resource

ARG git_resource_version=1.16.0
WORKDIR /root

RUN apk --no-cache add \
  bash \
  curl \
  git \
  git-crypt \
  git-daemon \
  git-lfs \
  gnupg \
  jq \
  openssl-dev \
  make \
  g++ \
  openssh-client \
  tar \
  libstdc++ \
  coreutils \
&& git clone https://github.com/proxytunnel/proxytunnel.git && \
  cd proxytunnel && \
  make -j4 && \
  install -c proxytunnel /usr/bin/proxytunnel && \
  cd .. && \
  rm -rf proxytunnel \
&& git config --global user.email "git@localhost" \
&& git config --global user.name "git" \
&& git clone --depth 1 --branch v${git_resource_version} https://github.com/concourse/git-resource \
&& mkdir -p /opt/resource \
&& cp /root/git-resource/assets/* /opt/resource/ \
&& chmod +x /opt/resource/* \
&& export CXXFLAGS="-DOPENSSL_API_COMPAT=0x30000000L" \
&& rm -rf /root/git-resource \
&& cd /usr/libexec/git-core \
&& rm -f \
      git-add \
      git-add--interactive \
      git-annotate \
      git-apply \
      git-archimport \
      git-archive \
      git-bisect--helper \
      git-blame \
      git-branch \
      git-bundle \
      git-credential-cache \
      git-credential-cache--daemon \
      git-credential-store \
      git-cat-file \
      git-check-attr \
      git-check-ignore \
      git-check-mailmap \
      git-check-ref-format \
      git-checkout \
      git-checkout-index \
      git-cherry \
      git-cherry-pick \
      git-clean \
      git-clone \
      git-column \
      git-commit \
      git-commit-tree \
      git-config \
      git-count-objects \
      git-credential \
      git-cvsexportcommit \
      git-cvsimport \
      git-cvsserver \
      git-describe \
      git-diff \
      git-diff-files \
      git-diff-index \
      git-diff-tree \
      git-difftool \
      git-fast-export \
      git-fast-import \
      git-fetch \
      git-fetch-pack \
      git-fmt-merge-msg \
      git-for-each-ref \
      git-format-patch \
      git-fsck \
      git-fsck-objects \
      git-gc \
      git-get-tar-commit-id \
      git-grep \
      git-hash-object \
      git-help \
      git-http-backend\
      git-imap-send \
      git-index-pack \
      git-init \
      git-init-db \
      git-lfs \
      git-log \
      git-ls-files \
      git-ls-remote \
      git-ls-tree \
      git-mailinfo \
      git-mailsplit \
      git-merge \
      git-mktag \
      git-mktree \
      git-mv \
      git-name-rev \
      git-notes \
      git-p4 \
      git-pack-objects \
      git-pack-redundant \
      git-pack-refs \
      git-patch-id \
      git-peek-remote \
      git-prune \
      git-prune-packed \
      git-push \
      git-read-tree \
      git-reflog \
      git-relink \
      git-remote \
      git-remote-ext \
      git-remote-fd \
      git-remote-testsvn \
      git-repack \
      git-replace \
      git-repo-config \
      git-rerere \
      git-reset \
      git-rev-list \
      git-rev-parse \
      git-revert \
      git-rm \
      git-send-email \
      git-send-pack \
      git-shell \
      git-shortlog \
      git-show \
      git-show-branch \
      git-show-index \
      git-show-ref \
      git-stage \
      git-show-ref \
      git-stage \
      git-status \
      git-stripspace \
      git-svn \
      git-symbolic-ref \
      git-tag \
      git-tar-tree \
      git-unpack-file \
      git-unpack-objects \
      git-update-index \
      git-update-ref \
      git-update-server-info \
      git-upload-archive \
      git-var \
      git-verify-pack \
      git-verify-tag \
      git-whatchanged \
      git-write-tree \
&& ln -s /usr/libexec/git-core/git /usr/libexec/git-core/git-merge \
&& cd /usr/share \
&& rm -rf \
    gitweb \
    locale \
    perl \
    perl5 \
&& cd /usr/lib \
&& rm -rf \
  perl \
  perl5 \
&&  curl http://aia.pki.co.sap.com/aia/SAP%20Global%20Root%20CA.crt -o \
  /usr/local/share/ca-certificates/SAP_Global_Root_CA.crt \
&& curl http://aia.pki.co.sap.com/aia/SAPNetCA_G2.crt -o \
    /usr/local/share/ca-certificates/SAPNetCA_G2.crt \
&& curl http://aia.pki.co.sap.com/aia/SAP%20Global%20Sub%20CA%2004.crt -o \
    /usr/local/share/ca-certificates/SAP_Global_Sub_CA_04.crt \
&& curl http://aia.pki.co.sap.com/aia/SAP%20Global%20Sub%20CA%2005.crt -o \
    /usr/local/share/ca-certificates/SAP_Global_Sub_CA_05.crt \
&& update-ca-certificates \
&& dos2unix /etc/ssl/certs/ca-certificates.crt \
&& cp /etc/ssl/certs/ca-certificates.crt /ca-certificates-overwrite.crt \
&& cat /usr/local/share/ca-certificates/SAP_Global_Root_CA.crt >> /ca-certificates-overwrite.crt \
&& git config --global http.sslCAInfo "/ca-certificates-overwrite.crt" \
&& apk del --no-cache \
  openssl-dev \
  make \
  g++

ENV CURL_CA_BUNDLE=/ca-certificates-overwrite.crt

FROM resource
