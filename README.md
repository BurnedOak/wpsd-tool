Philosophie & Konzept


WPSD ist eine hervorragende und mächtige Dashboard-Plattform für digitale Hotspots. Es hat jedoch eine architektonische Eigenheit: Bei Speicherungen im Web-Interface werden oft individuelle Routing-Entscheidungen (wie manuell angelegte statische Talkgroups oder erweiterte Rewrite-Regeln) im Hintergrund gnadenlos überschrieben oder gelöscht.

Dieses WPSD - Gateway Tool gibt dem Funker die volle Kontrolle über sein Gateway zurück. Es agiert als echter Watchdog (Wächter): Es analysiert die Konfiguration tiefgreifend bis auf die Dateisystemebene, deckt unautorisierte Änderungen auf und ermöglicht die sofortige Wiederherstellung einer gesicherten Master-Konfiguration. Du kannst WPSD endlich "unter die Haube" schauen und exakt verstehen, wie dein Traffic geroutet wird.

Zero-Overhead Architektur: Das gesamte Tool besteht aus einem einzigen, hochoptimierten Bash-Skript. Es benötigt keine Datenbanken, keine ressourcenfressenden Hintergrunddienste (Dämonen) und keine externen APIs. Der Ressourcenverbrauch (CPU/RAM) auf dem Hotspot liegt bei exakt 0%, wenn das Tool nicht gerade aktiv vom Benutzer aufgerufen oder einmalig in der Nacht durch den winzigen Cronjob getriggert wird.

Experimenteller Charakter: Dieses Tool greift aktiv in das Dateisystem und die Dienste des Hotspots ein. Die Nutzung erfolgt ausdrücklich auf eigene Gefahr.

Please be aware, this is an experimental beta version! You´re free to do anything at your own risc!
