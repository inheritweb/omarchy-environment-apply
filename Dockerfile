FROM archlinux:latest

RUN pacman -Syu --noconfirm --needed \
    bash \
    curl \
    edk2-ovmf \
    git \
    jq \
    python-pip \
    qemu-img \
    qemu-system-x86 \
    samba \
    wget \
 && pip install --break-system-packages --no-cache-dir vncdotool \
 && pacman -Scc --noconfirm

EXPOSE 5900

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace

CMD ["/entrypoint.sh"]
