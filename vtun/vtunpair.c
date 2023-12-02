#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <unistd.h>

#include <linux/if.h>
#include <linux/if_tun.h>
#include <argp.h>

#define max(a,b) ((a)>(b) ? (a):(b))

const char *argp_program_version =
  "vtunpair 1.0";
const char *argp_program_bug_address =
  "lakshmankumar@gmail.com";

static char doc[] =
  "vtunpair -- creates a pair of tun interfaces, that echo each other pkts\n"
  "            Supply the names of the 2 tun interfaces to create\n";

static char args_doc[] = "tun1 tun2";

static struct argp_option options[] = {
    {"persistent",  'p', 0,      0,  "Create persistent tunnels" },
    {"pidfile",     'P', "pidfile", 0,  "pid file to create"},
    { 0 }
};

struct arguments
{
    const char *tun1;
    const char *tun2;
    int         persistent;
    const char *pidfile;
};

static error_t parse_opt (int key, char *arg, struct argp_state *state)
{
    struct arguments *arguments = state->input;

    switch (key)
    {
        case 'p':
            arguments->persistent = 1;
            break;
        case 'P':
            arguments->pidfile = arg;
            break;
        case ARGP_KEY_ARG:
            if (state->arg_num >= 2) {
                fprintf(stderr, "Too many args\n");
                argp_usage (state);
            } else if (state->arg_num == 0) {
                arguments->tun1 = arg;
            } else { /* state->arg_num == 1 */
                arguments->tun2 = arg;
            }
            break;
        case ARGP_KEY_END:
            if (state->arg_num < 2) {
                fprintf(stderr, "Too few args\n");
                argp_usage (state);
            }
            break;
        default:
            return ARGP_ERR_UNKNOWN;
    }
    return 0;
}

static struct argp argp = { options, parse_opt, args_doc, doc };

static int create_tunnel(struct arguments *args, const char *tun)
{
    char *clonedev = "/dev/net/tun";

    int fd = open(clonedev, O_RDWR);
    if( fd < 0 ) {
        fprintf(stderr, "cloning %s failed while attempting tun:%s, err:%d/%s\n",
                        clonedev, tun, errno, strerror(errno));
        exit(1);
    }

    struct ifreq ifr;
    memset(&ifr, 0, sizeof(ifr));
    ifr.ifr_flags = IFF_TUN | IFF_NO_PI;
    strncpy(ifr.ifr_name, tun, IFNAMSIZ);

    int err = ioctl(fd, TUNSETIFF, (void *) &ifr);
    if( err < 0 ) {
        fprintf(stderr, "tun:%s ioctl-TUNSETIFF failed, err:%d/%s\n",
                        tun, errno, strerror(errno));
        exit (1);
    }

    err = ioctl(fd, TUNSETPERSIST, args->persistent);
    if( err < 0 ) {
        fprintf(stderr, "tun:%s TUNSETPERSIST-%d failed, err:%d/%s\n",
                        tun, args->persistent, errno, strerror(errno));
        exit(1);
    }
    err = ioctl(fd, TUNSETNOCSUM, 1);
    if ( err < 0 ) {
        fprintf(stderr, "tun:%s TUNSETNOCSUM failed, err:%d/%s\n",
                        tun, errno, strerror(errno));
        exit(1);
    }

    return fd;
}

int main(int argc, char *argv[])
{
    struct arguments arguments;

    /* Default values. */
    arguments.persistent = 0;
    arguments.pidfile = NULL;

    argp_parse (&argp, argc, argv, 0, 0, &arguments);

    if (arguments.pidfile) {
        FILE *f = fopen(arguments.pidfile, "w");
        if (!f) {
            fprintf(stderr, "Unable to open pidfile:%s\n", arguments.pidfile);
            exit(1);
        }
        int err = fprintf(f,"%d",getpid());
        if (err <= 0) {
            fprintf(stderr, "Unable to write to pidfile:%s\n", arguments.pidfile);
            exit(1);
        }
        fclose(f);
    }

    int fd1 = create_tunnel(&arguments, arguments.tun1);
    int fd2 = create_tunnel(&arguments, arguments.tun2);

    int fm = max(fd1, fd2) + 1;

    while(1){
        fd_set fds;
        char buf[1600];
        FD_ZERO(&fds);
        FD_SET(fd1, &fds);
        FD_SET(fd2, &fds);

        select(fm, &fds, NULL, NULL, NULL);

        if(FD_ISSET(fd1, &fds) ) {
            int l = read(fd1,buf,sizeof(buf));
            write(fd2,buf,l);
        }
        if( FD_ISSET(fd2, &fds) ) {
            int l = read(fd2,buf,sizeof(buf));
            write(fd1,buf,l);
        }
    }
    return 0;
}

