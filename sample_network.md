# Sample Network

```
                                                          Internet
                                                               |
                                                               |e0
           +---------+     +---------+    +---------+     +----+----+
           | N-Host1 |     | N-Host2 |    | N-Host3 |     | Edge-Rtr|
           +----+----+     +----+----+    +----+----+     +----+----+
                |.3             |.4            |.5           e1|.2
           -----+---------------+--------------+------+--------+----  192.168.159.*/24
                                                    e0|.1
                                                 +----+----+
                                                 | N-Rtr   |
                                                 +----+----+
                                                  ntun|.1
                                                      |     192.168.160.*/24
                                                  stun|.2
                                                 +----+----+
                                                 | S-Rtr   |
                                                 +----+----+
                                                    e0|.1
                          ------+--------------+------+--------+----  192.168.162.*/24
                              e0|.2            |.3             |.4
    +---------+ wtun     .2+----+----+    +----+----+     +----+----+
    |SW-Host1 +------------+ S-Host1 |    | S-Host2 |     | S-Host3 |
    +---------+.1    swtun +---------+    +---------+     +---------+

             192.168.163.*/24

```
