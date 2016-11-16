FROM scratch
ADD ./output/rootfs.tar.gz /

CMD ["/bin/bash"]
