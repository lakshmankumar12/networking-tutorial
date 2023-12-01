#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/ioctl.h>

#include <linux/if.h>
#include <linux/if_tun.h>

#define max(a,b) ((a)>(b) ? (a):(b))

int main(int argc, char *argv[])
{
    int err;
    if(argc < 3) {
        printf("Usage: tunpair name1 name2\n");
        exit(1);
    }
    char *clonedev = "/dev/net/tun";
    int firstfd;

    /* open the clone device */
    if( (firstfd = open(clonedev, O_RDWR)) < 0 ) {
        perror("Could't open clonedev");
        return firstfd;
    }

    struct ifreq ifr;
    memset(&ifr, 0, sizeof(ifr));
    ifr.ifr_flags = IFF_TUN | IFF_NO_PI;
    strncpy(ifr.ifr_name, argv[1], IFNAMSIZ);

    /* try to create the device */
    if( (err = ioctl(firstfd, TUNSETIFF, (void *) &ifr)) < 0 ) {
        perror("ioctl failed for first tun");
        return err;
    }

    if(ioctl(firstfd, TUNSETPERSIST, 1) < 0){
        perror("disabling TUNSETPERSIST");
        return -1;
    }
    if (ioctl(firstfd, TUNSETNOCSUM, 1) < 0) {
        perror("disabling CSUM");
        return -1;
    }

    /* open the clone device */
    int secondfd;
    if( (secondfd = open(clonedev, O_RDWR)) < 0 ) {
        perror("Could't open clonedev");
        return secondfd;
    }

    memset(&ifr, 0, sizeof(ifr));
    ifr.ifr_flags = IFF_TUN | IFF_NO_PI;
    strncpy(ifr.ifr_name, argv[2], IFNAMSIZ);

    /* try to create the device */
    if( (err = ioctl(secondfd, TUNSETIFF, (void *) &ifr)) < 0 ) {
        perror("ioctl failed for second tun");
        return err;
    }

    if(ioctl(secondfd, TUNSETPERSIST, 1) < 0){
        perror("disabling TUNSETPERSIST");
        return -1;
    }
    if (ioctl(secondfd, TUNSETNOCSUM, 1) < 0) {
        perror("disabling CSUM");
        return -1;
    }

    int fm = max(firstfd, secondfd) + 1;

    while(1){
        fd_set fds;
        char buf[1600];
        FD_ZERO(&fds);
        FD_SET(firstfd, &fds);
        FD_SET(secondfd, &fds);

        select(fm, &fds, NULL, NULL, NULL);

        if(FD_ISSET(firstfd, &fds) ) {
            int l = read(firstfd,buf,sizeof(buf));
            write(secondfd,buf,l);
        }
        if( FD_ISSET(secondfd, &fds) ) {
            int l = read(secondfd,buf,sizeof(buf));
            write(firstfd,buf,l);
        }
    }
    return 0;
}

