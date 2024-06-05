BEGIN {
    counter = -1;
}

{
    if ($1 == "*") {
        counter++;
        if (FNR == 1) {
            printf("    %s\n", $0)
        } else {
            printf("%3d %s\n", counter, $0)
        }
    } else {
        printf("    %s\n", $0)
    }
}
