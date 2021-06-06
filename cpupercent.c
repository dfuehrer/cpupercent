#include <stdio.h>
#include "libdrawille/Canvas.h"
#include "libdrawille/utils.h"

int main(int argv, char ** argc){
    FILE * file = fopen("/proc/stat", "r");
    long user, nice, system, idle, iowait, irq, softirq, steal, guest;
    fscanf(file, "cpu %d %d %d %d %d %d %d %d %d", &user, &nice, &system, &idle, &iowait, &irq, &softirq, &steal, &guest);
    printf("CPU: %d %d %d %d %d %d %d %d %d\n", user, nice, system, idle, iowait, irq, softirq, steal, guest);
    long active = user + system + nice + softirq + steal;
    long total  = active + idle + iowait;
    printf("active: %d, total %d\n", active, total);

    Canvas * c = new_canvas(8, 8);
    char ** buff = new_buffer(c);
    set_pixel(c, WHITE, 2, 4);
    set_pixel(c, WHITE, 5, 6);
    free_buffer(buff);
    return 0;
}
