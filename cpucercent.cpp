#include <iostream>
#include <fstream>
#include <string>
#include <array>
#include <locale>
#include "../drawille-plusplus/drawille.hpp"
#include <cstdio>



/* int main(int argv, char ** argc){ */
int main(){

    std::locale::global(std::locale(""));

    std::ifstream statFile("/proc/stat");
    std::string cpu;

    long user, nice, system, idle, iowait, irq, softirq, steal;
    statFile >> cpu >> user >> nice >> system >> idle >> iowait >> irq >> softirq >> steal;
    statFile.close();

    long active = user + system + nice + softirq + steal;
    long total  = active + idle + iowait;
    /* std::cout << active << ' ' << total << '\n'; */

    std::ifstream istore("/home/dfuehrer/.cache/dwmblocks/cpupercent/cpupercent.txt");
    long pactive = 0, ptotal = 0, percent;
    std::array<long, 7> pperc = {0};
    if(istore.is_open()){
        istore >> pactive >> ptotal;
        /* std::cout << pactive << ' ' << ptotal << '\n'; */
        percent = (active - pactive) * 100 / (total - ptotal);
        /* std::cout << percent << "%\n"; */
        for(long & perc: pperc){
            istore >> perc;
        }
        /* for(long perc: pperc){ */
        /*     std::cout << perc; */
        /* } */
        /* std::cout << '\n'; */
    }
    istore.close();



    Drawille::Canvas c(4, 1);
    c.set(7, 3 - percent / 25);
    for(int i = 0; i < pperc.size(); i++){
        c.set(6 - i, 3 - pperc[i] / 25);
    }
    c.draw(std::wcout);


    std::ofstream store("/home/dfuehrer/.cache/dwmblocks/cpupercent/cpupercent.txt");
    store << active << ' ' << total << '\n';
    store << percent << '\n';
    for(long perc: pperc){
        if(perc == *pperc.end())   break;
        store << perc << '\n';
        /* std::cout << perc << '\n'; */
    }
    store.close();

    /* std::wcout << "\10\10\10\10" << std::format("{3d}%\n", percent); */
    std::wprintf(L"%3d%%\n", percent);
    

    return 0;
}
