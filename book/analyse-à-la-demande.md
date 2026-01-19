> La littérature est constituée d'arrangements idiosyncratiques en lignes horizontales de seulement vingt-six symboles phonétiques, dix chiffres arabes, et environ huit signes de ponctuation.
>
> <cite>Kurt Vonnegut, <em>Like Shaking Hands With God: A Conversation about Writing</em></cite>

Notre second interpréteur, clox, a trois phases -- scanner, compilateur, et machine virtuelle. Une structure de données joint chaque paire de phases. Les tokens coulent du scanner au compilateur, et des morceaux de bytecode du compilateur vers la VM. Nous avons commencé notre implémentation près de la fin avec les [morceaux][chunks] et la [VM][]. Maintenant, nous allons sauter en arrière au début et construire un scanner qui fabrique des tokens. Dans le [prochain chapitre][next chapter], nous lierons les deux bouts ensemble avec notre compilateur bytecode.

[chunks]: morceaux-de-bytecode.html
[vm]: machine-virtuelle.html
[next chapter]: compilation-des-expressions.html

<img src="image/scanning-on-demand/pipeline.png" alt="Code source &rarr; scanner &rarr; tokens &rarr; compilateur &rarr; morceau de bytecode &rarr; VM." />

J'admettrai, ce n'est pas le chapitre le plus excitant du livre. Avec deux implémentations du même langage, il y a forcément un peu de redondance. Je me suis faufilé dans quelques différences intéressantes comparées au scanner de jlox. Lisez la suite pour voir ce qu'elles sont.

## Démarrer l'interpréteur

Maintenant que nous construisons le front end, nous pouvons faire tourner clox comme un vrai interpréteur. Plus de morceaux de bytecode écrits à la main. Il est temps pour un REPL et le chargement de script. Arrachez la plupart du code dans `main()` et remplacez-le par :

^code args (3 before, 2 after)

Si vous ne passez <span name="args">aucun argument</span> à l'exécutable, vous êtes largué dans le REPL. Un unique argument de ligne de commande est compris comme étant le chemin vers un script à exécuter.

<aside name="args">

Le code teste pour un et deux arguments, pas zéro et un, parce que le premier argument dans `argv` est toujours le nom de l'exécutable étant exécuté.

</aside>

Nous aurons besoin de quelques en-têtes système, donc sortons-les tous du chemin.

^code main-includes (1 after)

Ensuite, nous mettons le REPL debout et REPL-ant.

^code repl (1 before)

Un REPL de qualité gère l'entrée qui s'étend sur de multiples lignes avec grâce et n'a pas une limite de longueur de ligne codée en dur. Ce REPL ici est un peu plus, hmm, austère, mais il est bien pour nos objectifs.

Le vrai travail se passe dans `interpret()`. Nous y arriverons bientôt, mais d'abord prenons soin de charger les scripts.

^code run-file

Nous lisons le fichier et exécutons la chaîne de code source Lox résultante. Ensuite, basé sur le résultat de cela, nous définissons le code de sortie de manière appropriée parce que nous sommes des constructeurs d'outils scrupuleux et nous nous soucions des petits détails comme ça.

Nous avons aussi besoin de libérer la chaîne de code source parce que `readFile()` l'alloue dynamiquement et passe la propriété à son appelant. Cette fonction ressemble à ceci :

<aside name="owner">

C nous demande non seulement de gérer la mémoire explicitement, mais _mentalement_. Nous programmeurs devons nous souvenir des règles de propriété et les implémenter à la main à travers le programme. Java le fait juste pour nous. C++ nous donne des outils pour encoder la politique directement de sorte que le compilateur la valide pour nous.

J'aime la simplicité du C, mais nous payons un prix réel pour elle -- le langage exige de nous d'être plus consciencieux.

</aside>

^code read-file

Comme beaucoup de code C, cela prend plus d'effort qu'il semble que cela devrait, spécialement pour un langage expressément conçu pour les systèmes d'exploitation. La partie difficile est que nous voulons allouer une chaîne assez grande pour lire le fichier entier, mais nous ne savons pas combien le fichier est grand jusqu'à ce que nous l'ayons lu.

Le code ici est le truc classique pour résoudre ça. Nous ouvrons le fichier, mais avant de le lire, nous cherchons (seek) jusqu'à la toute fin en utilisant `fseek()`. Ensuite nous appelons `ftell()` qui nous dit à combien d'octets nous sommes du début du fichier. Puisque nous avons cherché jusqu'à la fin, c'est la taille. Nous rembobinons au début, allouons une chaîne de cette <span name="one">taille</span>, et lisons le fichier entier en un seul lot.

<aside name="one">

Eh bien, cette taille _plus un_. Toujours se souvenir de faire de la place pour l'octet nul.

</aside>

Donc nous avons fini, n'est-ce pas ? Pas tout à fait. Ces appels de fonction, comme la plupart des appels dans la bibliothèque standard C, peuvent échouer. Si c'était du Java, les échecs seraient levés comme des exceptions et dérouleraient automatiquement la pile donc nous n'aurions pas _vraiment_ besoin de les gérer. En C, si nous ne vérifions pas pour eux, ils sont silencieusement ignorés.

Ce n'est pas vraiment un livre sur les bonnes pratiques de programmation C, mais je déteste encourager le mauvais style, donc allons-y et gérons les erreurs. C'est bon pour nous, comme manger nos légumes ou passer le fil dentaire.

Heureusement, nous n'avons pas besoin de faire quoi que ce soit de particulièrement intelligent si un échec se produit. Si nous ne pouvons pas lire correctement le script de l'utilisateur, tout ce que nous pouvons vraiment faire est de le dire à l'utilisateur et de quitter l'interpréteur avec grâce. D'abord, nous pourrions échouer à ouvrir le fichier.

^code no-file (1 before, 2 after)

Cela peut arriver si le fichier n'existe pas ou si l'utilisateur n'a pas accès à lui. C'est assez commun -- les gens font des fautes de frappe dans les chemins tout le temps.

Cet échec est beaucoup plus rare :

^code no-buffer (1 before, 1 after)

Si nous ne pouvons même pas allouer assez de mémoire pour lire le script Lox, l'utilisateur a probablement de plus gros problèmes dont s'inquiéter, mais nous devrions faire de notre mieux pour au moins leur faire savoir.

Finalement, la lecture elle-même peut échouer.

^code no-read (1 before, 1 after)

C'est aussi improbable. En fait, les <span name="printf">appels</span> à `fseek()`, `ftell()`, et `rewind()` pourraient théoriquement échouer aussi, mais n'allons pas trop loin dans les mauvaises herbes, d'accord ?

<aside name="printf">

Même le bon vieux `printf()` peut échouer. Ouaip. Combien de fois avez-vous géré _cette_ erreur ?

</aside>

### Ouvrir le pipeline de compilation

Nous avons nous-mêmes une chaîne de code source Lox, donc maintenant nous sommes prêts à mettre en place un pipeline pour la scanner, la compiler, et l'exécuter. C'est piloté par `interpret()`. En ce moment, cette fonction exécute notre vieux morceau de test écrit en dur. Changeons-la pour quelque chose de plus proche de son incarnation finale.

^code vm-interpret-h (1 before, 1 after)

Là où avant nous passions un Chunk, maintenant nous passons la chaîne de code source. Voici la nouvelle implémentation :

^code vm-interpret-c (1 after)

Nous ne construirons pas le _compilateur_ réel encore dans ce chapitre, mais nous pouvons commencer à disposer sa structure. Il vit dans un nouveau module.

^code vm-include-compiler (1 before, 1 after)

Pour l'instant, la seule fonction dedans est déclarée comme ceci :

^code compiler-h

Cette signature changera, mais cela nous lance.

La première phase de la compilation est le scan -- la chose que nous faisons dans ce chapitre -- donc en ce moment tout ce que le compilateur fait est de mettre cela en place.

^code compiler-c

Cela aussi grandira dans les chapitres ultérieurs, naturellement.

### Le scanner scanne

Il y a encore quelques pieds de plus d'échafaudage à dresser avant que nous puissions commencer à écrire du code utile. D'abord, un nouvel en-tête :

^code scanner-h

Et son implémentation correspondante :

^code scanner-c

Alors que notre scanner mâche à travers le code source de l'utilisateur, il suit jusqu'où il est allé. Comme nous l'avons fait avec la VM, nous enveloppons cet état dans une struct et ensuite créons une unique variable de module de haut niveau de ce type afin que nous n'ayons pas à la passer à tous les différentes fonctions.

Il y a étonnamment peu de champs. Le pointeur `start` marque le début du lexème courant étant scanné, et `current` pointe vers le caractère courant étant regardé.

<span name="fields"></span>

<img src="image/scanning-on-demand/fields.png" alt="Les champs start et current pointant vers 'print bacon;'. Start pointe vers 'b' et current pointe vers 'o'." />

<aside name="fields">

Ici, nous sommes au milieu du scan de l'identifiant `bacon`. Le caractère courant est `o` et le caractère que nous avons consommé le plus récemment est `c`.

</aside>

Nous avons un champ `line` pour suivre sur quelle ligne est le lexème courant pour le rapport d'erreurs. C'est tout ! Nous ne gardons même pas un pointeur vers le début de la chaîne de code source. Le scanner travaille son chemin à travers le code une fois et a fini après ça.

Puisque nous avons un peu d'état, nous devrions l'initialiser.

^code init-scanner

Nous commençons au tout premier caractère sur la toute première ligne, comme un coureur accroupi sur la ligne de départ.

## Un Token à la Fois

Dans jlox, quand le pistolet de départ partait, le scanner fonçait en avant et scannait avidement le programme entier, renvoyant une liste de tokens. Ce serait un défi dans clox. Nous aurions besoin d'une sorte de tableau ou liste grandissant pour stocker les tokens dedans. Nous aurions besoin de gérer l'allocation et la libération des tokens, et la collection elle-même. C'est beaucoup de code, et beaucoup de barattage de mémoire.

À n'importe quel point dans le temps, le compilateur a besoin seulement d'un ou deux tokens -- rappelez-vous notre grammaire exige seulement un unique token d'avance (lookahead) -- donc nous n'avons pas besoin de les garder _tous_ dans le coin au même moment. Au lieu de cela, la solution la plus simple est de ne pas scanner un token jusqu'à ce que le compilateur en ait besoin d'un. Quand le scanner en fournit un, il renvoie le token par valeur. Il n'a pas besoin d'allouer dynamiquement quoi que ce soit -- il peut juste passer les tokens autour sur la pile C.

Malheureusement, nous n'avons pas de compilateur encore qui peut demander des tokens au scanner, donc le scanner restera juste assis là à ne rien faire. Pour le botter en action, nous écrirons un peu de code temporaire pour le piloter.

^code dump-tokens (1 before, 1 after)

<aside name="format">

Ce `%.*s` dans la chaîne de format est une fonctionnalité chouette. Habituellement, vous définissez la précision de sortie -- le nombre de caractères à montrer -- en plaçant un nombre à l'intérieur de la chaîne de format. Utiliser `*` à la place vous laisse passer la précision comme un argument. Donc cet appel à `printf()` imprime les `token.length` premiers caractères de la chaîne à `token.start`. Nous avons besoin de limiter la longueur comme ça parce que le lexème pointe dans la chaîne source originale et n'a pas de terminateur à la fin.

</aside>

Ceci boucle indéfiniment. Chaque tour à travers la boucle, il scanne un token et l'imprime. Quand il atteint un token spécial "fin de fichier" ou une erreur, il s'arrête. Par exemple, si nous lançons l'interpréteur sur ce programme :

```lox
print 1 + 2;
```

Il imprime :

```text
   1 31 'print'
   | 21 '1'
   |  7 '+'
   | 21 '2'
   |  8 ';'
   2 39 ''
```

La première colonne est le numéro de ligne, la seconde est la valeur numérique du <span name="token">type</span> de token, et ensuite finalement le lexème. Ce dernier lexème vide sur la ligne 2 est le token EOF.

<aside name="token">

Ouais, l'index brut du type de token n'est pas exactement lisible par un humain, mais c'est tout ce que C nous donne.

</aside>

Le but pour le reste du chapitre est de faire marcher ce blob de code en implémentant cette fonction clé :

^code scan-token-h (1 before, 2 after)

Chaque appel scanne et renvoie le prochain token dans le code source. Un token ressemble à ceci :

^code token-struct (1 before, 2 after)

C'est assez similaire à la classe Token de jlox. Nous avons un enum identifiant quel type de token c'est -- nombre, identifiant, opérateur `+`, etc. L'enum est virtuellement identique à celui dans jlox, donc martelons juste la chose entière.

^code token-type (2 before, 2 after)

À part préfixer tous les noms avec `TOKEN_` (puisque C jette les noms d'enum dans l'espace de noms de haut niveau) la seule différence est ce type `TOKEN_ERROR` supplémentaire. C'est à propos de quoi ?

Il y a seulement une couple d'erreurs qui sont détectées durant le scan : les chaînes non terminées et les caractères non reconnus. Dans jlox, le scanner rapporte celles-ci lui-même. Dans clox, le scanner produit un token "erreur" synthétique pour cette erreur et le passe au compilateur. De cette façon, le compilateur sait qu'une erreur s'est produite et peut déclencher la récupération d'erreur avant de la rapporter.

La partie nouvelle dans le type Token de clox est comment il représente le lexème. Dans jlox, chaque Token stockait le lexème comme sa propre petite chaîne Java séparée. Si nous faisions cela pour clox, nous devrions trouver comment gérer la mémoire pour ces chaînes. C'est spécialement dur puisque nous passons les tokens par valeur -- de multiples tokens pourraient pointer vers la même chaîne de lexème. La propriété devient bizarre.

Au lieu de cela, nous utilisons la chaîne source originale comme notre stockage de caractères. Nous représentons un lexème par un pointeur vers son premier caractère et le nombre de caractères qu'il contient. Cela signifie que nous n'avons pas besoin de nous inquiéter de gérer la mémoire pour les lexèmes du tout et nous pouvons copier librement les tokens autour. Tant que la chaîne de code source principale <span name="outlive">survit</span> à tous les tokens, tout fonctionne bien.

<aside name="outlive">

Je ne veux pas paraître désinvolte. Nous avons vraiment besoin de penser à et assurer que la chaîne source, qui est créée loin là-bas dans le module "main", a une durée de vie assez longue. C'est pourquoi `runFile()` ne libère pas la chaîne jusqu'à ce que `interpret()` finisse d'exécuter le code et revienne.

</aside>

### Scanner les tokens

Nous sommes prêts à scanner quelques tokens. Nous travaillerons notre chemin vers l'implémentation complète, commençant avec ceci :

^code scan-token

Puisque chaque appel à cette fonction scanne un token complet, nous savons que nous sommes au début d'un nouveau token quand nous entrons dans la fonction. Ainsi, nous définissons `scanner.start` pour pointer vers le caractère courant afin que nous nous souvenions où commence le lexème que nous sommes sur le point de scanner.

Ensuite nous vérifions pour voir si nous avons atteint la fin du code source. Si c'est le cas, nous renvoyons un token EOF et arrêtons. C'est une valeur sentinelle qui signale au compilateur d'arrêter de demander plus de tokens.

Si nous ne sommes pas à la fin, nous faisons quelques... trucs... pour scanner le prochain token. Mais nous n'avons pas écrit ce code encore. Nous y arriverons bientôt. Si ce code ne scanne pas et ne renvoie pas avec succès un token, alors nous atteignons la fin de la fonction. Cela doit signifier que nous sommes à un caractère que le scanner ne peut pas reconnaître, donc nous renvoyons un token d'erreur pour cela.

Cette fonction compte sur une couple d'aides, dont la plupart sont familières de jlox. D'abord :

^code is-at-end

Nous exigeons que la chaîne source soit une bonne chaîne C terminée par nul. Si le caractère courant est l'octet nul, alors nous avons atteint la fin.

Pour créer un token, nous avons cette fonction semblable à un constructeur :

^code make-token

Elle utilise les pointeurs `start` et `current` du scanner pour capturer le lexème du token. Elle définit une couple d'autres champs évidents puis renvoie le token. Elle a une fonction sœur pour renvoyer les tokens d'erreur.

^code error-token

<span name="axolotl"></span>

<aside name="axolotl">

Cette partie du chapitre est assez sèche, donc voici une image d'un axolotl.

<img src="image/scanning-on-demand/axolotl.png" alt="Un dessin d'un axolotl." />

</aside>

La seule différence est que le "lexème" pointe vers la chaîne de message d'erreur au lieu de pointer dans le code source de l'utilisateur. Encore une fois, nous avons besoin d'assurer que le message d'erreur reste dans le coin assez longtemps pour que le compilateur le lise. En pratique, nous appelons seulement jamais cette fonction avec des littéraux de chaîne C. Ceux-ci sont constants et éternels, donc nous sommes bien.

Ce que nous avons maintenant est basiquement un scanner fonctionnel pour un langage avec une grammaire lexicale vide. Puisque la grammaire n'a pas de productions, chaque caractère est une erreur. Ce n'est pas exactement un langage amusant dans lequel programmer, donc remplissons les règles.

## Une Grammaire Lexicale pour Lox

Les tokens les plus simples sont seulement un caractère unique. Nous reconnaissons ceux-là comme ceci :

^code scan-char (1 before, 2 after)

Nous lisons le prochain caractère depuis le code source, et ensuite faisons un switch direct pour voir s'il correspond à n'importe lequel des lexèmes à un caractère de Lox. Pour lire le prochain caractère, nous utilisons une nouvelle aide qui consomme le caractère courant et le renvoie.

^code advance

Ensuite viennent les tokens de ponctuation à deux caractères comme `!=` et `>=`. Chacun de ceux-ci a aussi un token à un caractère correspondant. Cela signifie que quand nous voyons un caractère comme `!`, nous ne savons pas si nous sommes dans un token `!` ou un `!=` jusqu'à ce que nous regardions le caractère suivant aussi. Nous gérons ceux-là comme ceci :

^code two-char (1 before, 1 after)

Après avoir consommé le premier caractère, nous cherchons un `=`. Si trouvé, nous le consommons et renvoyons le token correspondant à deux caractères. Sinon, nous laissons le caractère courant seul (pour qu'il puisse faire partie du _prochain_ token) et renvoyons le token à un caractère approprié.

Cette logique pour consommer conditionnellement le second caractère vit ici :

^code match

Si le caractère courant est celui désiré, nous avançons et renvoyons `true`. Sinon, nous renvoyons `false` pour indiquer qu'il n'a pas été correspondu.

Maintenant notre scanner supporte tous les tokens de type ponctuation. Avant que nous arrivions aux plus longs, faisons un petit détour pour gérer les caractères qui ne font partie d'aucun token du tout.

### Espace blanc

Notre scanner a besoin de gérer les espaces, tabulations, et nouvelles lignes, mais ces caractères ne deviennent partie d'aucun lexème de token. Nous pourrions vérifier pour ceux-là à l'intérieur du switch de caractère principal dans `scanToken()` mais cela devient un peu délicat d'assurer que la fonction trouve encore correctement le prochain token _après_ l'espace blanc quand vous l'appelez. Nous devrions envelopper le corps entier de la fonction dans une boucle ou quelque chose.

Au lieu de cela, avant de commencer le token, nous dérivons vers une fonction séparée.

^code call-skip-whitespace (1 before, 1 after)

Ceci avance le scanner passé tout espace blanc de tête. Après que cet appel retourne, nous savons que le tout prochain caractère est un significatif (ou nous sommes à la fin du code source).

^code skip-whitespace

C'est une sorte de mini-scanner séparé. Il boucle, consommant chaque caractère d'espace blanc qu'il rencontre. Nous avons besoin d'être prudents qu'il ne consomme _pas_ de caractères _non_-espace blanc. Pour supporter cela, nous utilisons ceci :

^code peek

Ceci renvoie simplement le caractère courant, mais ne le consomme pas. Le code précédent gère tous les caractères d'espace blanc excepté les nouvelles lignes.

^code newline (1 before, 2 after)

Quand nous consommons une de celles-là, nous augmentons aussi le numéro de ligne courant.

### Commentaires

Les commentaires ne sont pas techniquement de "l'espace blanc", si vous voulez devenir tout précis avec votre terminologie, mais pour autant que Lox soit concerné, ils pourraient aussi bien en être, donc nous sautons ceux-là aussi.

^code comment (1 before, 2 after)

Les commentaires commencent avec `//` en Lox, donc comme avec `!=` et amis, nous avons besoin d'un second caractère d'avance. Cependant, avec `!=`, nous voulions toujours consommer le `!` même si le `=` n'était pas trouvé. Les commentaires sont différents. Si nous ne trouvons pas un second `/`, alors `skipWhitespace()` a besoin de ne pas consommer la _première_ barre oblique non plus.

Pour gérer cela, nous ajoutons :

^code peek-next

C'est comme `peek()` mais pour un caractère après le courant. Si le caractère courant et le suivant sont tous deux `/`, nous les consommons et ensuite n'importe quels autres caractères jusqu'à la prochaine nouvelle ligne ou la fin du code source.

Nous utilisons `peek()` pour vérifier la nouvelle ligne mais pas la consommer. De cette façon, la nouvelle ligne sera le caractère courant au prochain tour de la boucle extérieure dans `skipWhitespace()` et nous la reconnaîtrons et incrémenterons `scanner.line`.

### Tokens littéraux

Les tokens nombre et chaîne sont spéciaux parce qu'ils ont une valeur d'exécution associée avec eux. Nous commencerons avec les chaînes parce qu'elles sont faciles à reconnaître -- elles commencent toujours avec un guillemet double.

^code scan-string (1 before, 1 after)

Cela appelle une nouvelle fonction.

^code string

Similaire à jlox, nous consommons les caractères jusqu'à ce que nous atteignions le guillemet fermant. Nous suivons aussi les nouvelles lignes à l'intérieur du littéral de chaîne. (Lox supporte les chaînes multi-lignes.) Et, comme toujours, nous gérons avec grâce le fait de tomber à court de code source avant que nous trouvions le guillemet de fin.

Le changement principal ici dans clox est quelque chose qui n'est _pas_ présent. Encore une fois, cela se rapporte à la gestion de la mémoire. Dans jlox, la classe Token avait un champ de type Object pour stocker la valeur d'exécution convertie depuis le lexème du token littéral.

Implémenter cela en C exigerait beaucoup de travail. Nous aurions besoin d'une sorte d'union et d'étiquette de type pour dire si le token contient une chaîne ou une valeur double. Si c'est une chaîne, nous aurions besoin de gérer la mémoire pour le tableau de caractères de la chaîne d'une manière ou d'une autre.

Au lieu d'ajouter cette complexité au scanner, nous différons la <span name="convert">conversion</span> du lexème littéral en une valeur d'exécution jusqu'à plus tard. Dans clox, les tokens stockent seulement le lexème -- la séquence de caractères exactement comme elle apparaît dans le code source de l'utilisateur. Plus tard dans le compilateur, nous convertirons ce lexème en une valeur d'exécution juste quand nous sommes prêts à la stocker dans la table de constantes du morceau.

<aside name="convert">

Faire la conversion lexème-vers-valeur dans le compilateur introduit vraiment un peu de redondance. Le travail pour scanner un littéral nombre est terriblement similaire au travail requis pour convertir une séquence de caractères chiffres en une valeur de nombre. Mais il n'y a pas _tant_ de redondance que ça, ce n'est pas dans quelque chose de critique en performance, et cela garde notre scanner plus simple.

</aside>

Ensuite, les nombres. Au lieu d'ajouter un cas switch pour chacun des dix chiffres qui peuvent commencer un nombre, nous les gérons ici :

^code scan-number (1 before, 2 after)

Cela utilise cette fonction utilitaire évidente :

^code is-digit

Nous finissons de scanner le nombre en utilisant ceci :

^code number

C'est virtuellement identique à la version de jlox excepté, encore une fois, que nous ne convertissons pas le lexème en un double encore.

## Identifiants et Mots-clés

Le dernier lot de tokens sont les identifiants, à la fois définis par l'utilisateur et réservés. Cette section devrait être amusante -- la façon dont nous reconnaissons les mots-clés dans clox est assez différente de comment nous l'avons fait dans jlox, et touche à certaines structures de données importantes.

D'abord, cependant, nous devons scanner le lexème. Les noms commencent avec une lettre ou un souligné.

^code scan-identifier (1 before, 1 after)

Nous reconnaissons ceux-là en utilisant ceci :

^code is-alpha

Une fois que nous avons trouvé un identifiant, nous scannons le reste ici :

^code identifier

Après la première lettre, nous autorisons les chiffres aussi, et nous continuons de consommer les alphanumériques jusqu'à ce que nous tombions à court. Ensuite nous produisons un token avec le type approprié. Déterminer ce type "approprié" est la partie unique de ce chapitre.

^code identifier-type

O.K., je suppose que ce n'est pas très excitant encore. C'est ce à quoi ça ressemble si nous n'avons aucun mot réservé du tout. Comment devrions-nous nous y prendre pour reconnaître les mots-clés ? Dans jlox, nous les bourrions tous dans une Map Java et les cherchions par nom. Nous n'avons aucune sorte de structure de table de hachage dans clox, au moins pas encore.

Une table de hachage serait exagérée de toute façon. Pour chercher une chaîne dans une <span name="hash">table</span> de hachage, nous avons besoin de parcourir la chaîne pour calculer son code de hachage, trouver le seau correspondant dans la table de hachage, et ensuite faire une comparaison d'égalité caractère par caractère sur n'importe quelle chaîne qu'elle trouve là.

<aside name="hash">

Ne vous inquiétez pas si ceci ne vous est pas familier. Quand nous arriverons à [construire notre propre table de hachage depuis zéro][hash], nous apprendrons tout à son sujet dans un détail exquis.

[hash]: tables-de-hachage.html

</aside>

Disons que nous avons scanné l'identifiant "gorgonzola". Combien de travail _devrions_-nous avoir besoin de faire pour dire si c'est un mot réservé ? Eh bien, aucun mot-clé Lox ne commence par "g", donc regarder le premier caractère est suffisant pour répondre définitivement non. C'est beaucoup plus simple qu'une recherche dans une table de hachage.

Quoi à propos de "cardigan" ? Nous avons un mot-clé en Lox qui commence par "c" : "class". Mais le second caractère dans "cardigan", "a", écarte cela. Quoi à propos de "forest" ? Puisque "for" est un mot-clé, nous devons aller plus loin dans la chaîne avant que nous puissions établir que nous n'avons pas un mot réservé. Mais, dans la plupart des cas, seulement un caractère ou deux est suffisant pour dire que nous avons un nom défini par l'utilisateur sur les bras. Nous devrions être capables de reconnaître cela et d'échouer rapidement.

Voici une représentation visuelle de cette logique d'inspection de caractère branchée :

<span name="down"></span>

<img src="image/scanning-on-demand/keywords.png" alt="Un trie qui contient tous les mots-clés de Lox." />

<aside name="down">

Lisez vers le bas chaque chaîne de nœuds et vous verrez les mots-clés de Lox émerger.

</aside>

Nous commençons au nœud racine. S'il y a un nœud enfant dont la lettre correspond au premier caractère dans le lexème, nous bougeons vers ce nœud. Ensuite répétez pour la prochaine lettre dans le lexème et ainsi de suite. Si à n'importe quel point la prochaine lettre dans le lexème ne correspond pas à un nœud enfant, alors l'identifiant ne doit pas être un mot-clé et nous arrêtons. Si nous atteignons une boîte à double ligne, et que nous sommes au dernier caractère du lexème, alors nous avons trouvé un mot-clé.

### Tries et machines à états

Ce diagramme en arbre est un exemple d'une chose appelée un <span name="trie">[**trie**][trie]</span>. Un trie stocke un ensemble de chaînes. La plupart des autres structures de données pour stocker des chaînes contiennent les tableaux de caractères bruts et ensuite les enveloppent à l'intérieur de quelque plus grande construction qui vous aide à chercher plus vite. Un trie est différent. Nulle part dans le trie vous ne trouverez une chaîne entière.

[trie]: https://en.wikipedia.org/wiki/Trie

<aside name="trie">

"Trie" est un des noms les plus confus en informatique. Edward Fredkin l'a arraché du milieu du mot "retrieval" (récupération), ce qui signifie qu'il devrait être prononcé comme "tree" (arbre). Mais, euh, il y a déjà une structure de données assez importante prononcée "tree" _dont les tries sont un cas spécial_, donc à moins que vous ne parliez jamais de ces choses à voix haute, personne ne peut dire de laquelle vous parlez. Ainsi, les gens ces jours-ci le prononcent souvent comme "try" (essai) pour éviter le mal de tête.

</aside>

Au lieu de cela, chaque chaîne que le trie "contient" est représentée comme un _chemin_ à travers l'arbre de nœuds de caractères, comme dans notre traversée ci-dessus. Les nœuds qui correspondent au dernier caractère dans une chaîne ont un marqueur spécial -- les boîtes à double ligne dans l'illustration. De cette façon, si votre trie contient, disons, "banquet" et "ban", vous êtes capable de dire qu'il ne contient _pas_ "banque" -- le nœud "e" n'aura pas ce marqueur, tandis que les nœuds "n" et "t" l'auront.

Les tries sont un cas spécial d'une structure de données encore plus fondamentale : un [**automate fini déterministe**][dfa] (**AFD**). Vous pourriez aussi connaître ceux-ci par d'autres noms : **machine à états finis**, ou juste **machine à états**. Les machines à états sont rad. Elles finissent par être utiles dans tout, de la [programmation de jeux][state] à l'implémentation de protocoles réseau.

[dfa]: https://en.wikipedia.org/wiki/Deterministic_finite_automaton
[state]: http://gameprogrammingpatterns.com/state.html

Dans un AFD, vous avez un ensemble d'_états_ avec des _transitions_ entre eux, formant un graphe. À n'importe quel point dans le temps, la machine est "dans" exactement un état. Elle va vers d'autres états en suivant des transitions. Quand vous utilisez un AFD pour l'analyse lexicale, chaque transition est un caractère qui est correspondu depuis la chaîne. Chaque état représente un ensemble de caractères autorisés.

Notre arbre de mots-clés est exactement un AFD qui reconnaît les mots-clés Lox. Mais les AFD sont plus puissants que les simples arbres parce qu'ils peuvent être des _graphes_ arbitraires. Les transitions peuvent former des cycles entre états. Cela vous laisse reconnaître des chaînes arbitrairement longues. Par exemple, voici un AFD qui reconnaît les littéraux nombre :

<span name="railroad"></span>

<img src="image/scanning-on-demand/numbers.png" alt="Un diagramme syntaxique qui reconnaît les littéraux entiers et à virgule flottante." />

<aside name="railroad">

Ce style de diagramme est appelé un [**diagramme syntaxique**][syntax diagram] ou le plus charmant **diagramme ferroviaire**. Ce dernier nom est parce qu'il ressemble quelque peu à une cour de triage pour les trains.

Bien avant que la forme de Backus-Naur ne soit une chose, c'était une des manières prédominantes de documenter la grammaire d'un langage. De nos jours, nous utilisons surtout du texte, mais il y a quelque chose de délicieux à propos de la spécification officielle pour un _langage textuel_ reposant sur une _image_.

[syntax diagram]: https://en.wikipedia.org/wiki/Syntax_diagram

</aside>

J'ai effondré les nœuds pour les dix chiffres ensemble pour garder cela plus lisible, mais le processus de base fonctionne pareil -- vous travaillez à travers le chemin, entrant dans des nœuds chaque fois que vous consommez un caractère correspondant dans le lexème. Si nous étions ainsi enclins, nous pourrions construire un seul grand AFD géant qui fait _toute_ l'analyse lexicale pour Lox, une seule machine à états qui reconnaît et crache tous les tokens dont nous avons besoin.

Cependant, fabriquer ce méga-AFD à la <span name="regex">main</span> serait un défi. C'est pourquoi [Lex][] a été créé. Vous lui donnez une simple description textuelle de votre grammaire lexicale -- un tas d'expressions régulières -- et il génère automatiquement un AFD pour vous et produit une pile de code C qui l'implémente.

[lex]: https://en.wikipedia.org/wiki/Lex_(software)

<aside name="regex">

C'est aussi comme ça que la plupart des moteurs d'expressions régulières dans les langages de programmation et éditeurs de texte fonctionnent sous le capot. Ils prennent votre chaîne regex et la convertissent en un AFD, qu'ils utilisent ensuite pour correspondre des chaînes.

Si vous voulez apprendre l'algorithme pour convertir une expression régulière en un AFD, [le livre du dragon][dragon] vous couvre.

[dragon]: https://en.wikipedia.org/wiki/Compilers:_Principles,_Techniques,_and_Tools

</aside>

Nous n'irons pas sur cette route. Nous avons déjà un scanner roulé à la main parfaitement utilisable. Nous avons juste besoin d'un minuscule trie pour reconnaître les mots-clés. Comment devrions-nous mapper cela au code ?

La <span name="v8">solution</span> absolue la plus simple est d'utiliser une instruction switch pour chaque nœud avec des cas pour chaque branche. Nous commencerons avec le nœud racine et gérerons les mots-clés faciles.

<aside name="v8">

Simple ne veut pas dire bête. La même approche est [essentiellement ce que fait V8][v8], et c'est actuellement une des implémentations de langage les plus sophistiquées et les plus rapides du monde.

[v8]: https://github.com/v8/v8/blob/e77eebfe3b747fb315bd3baad09bec0953e53e68/src/parsing/scanner.cc#L1643

</aside>

^code keywords (1 before, 1 after)

Ce sont les lettres initiales qui correspondent à un seul mot-clé. Si nous voyons un "s", le seul mot-clé que l'identifiant pourrait possiblement être est `super`. Il pourrait ne pas l'être, cependant, donc nous avons encore besoin de vérifier le reste des lettres aussi. Dans le diagramme en arbre, c'est basiquement ce chemin droit pendant hors du "s".

Nous ne roulerons pas un switch pour chacun de ces nœuds. Au lieu de cela, nous avons une fonction utilitaire qui teste le reste du lexème d'un mot-clé potentiel.

^code check-keyword

Nous utilisons cela pour tous les chemins sans embranchement dans l'arbre. Une fois que nous avons trouvé un préfixe qui pourrait seulement être un mot réservé possible, nous avons besoin de vérifier deux choses. Le lexème doit être exactement aussi long que le mot-clé. Si la première lettre est "s", le lexème pourrait encore être "sup" ou "superb". Et les caractères restants doivent correspondre exactement -- "supar" n'est pas assez bon.

Si nous avons le bon nombre de caractères, et qu'ils sont ceux que nous voulons, alors c'est un mot-clé, et nous renvoyons le type de token associé. Sinon, ce doit être un identifiant normal.

Nous avons une couple de mots-clés où l'arbre branche encore après la première lettre. Si le lexème commence par "f", il pourrait être `false`, `for`, ou `fun`. Donc nous ajoutons un autre switch pour les branches venant du nœud "f".

^code keyword-f (1 before, 1 after)

Avant que nous switchions, nous avons besoin de vérifier qu'il y a même une seconde lettre. "f" par lui-même est un identifiant valide aussi, après tout. L'autre lettre qui branche est "t".

^code keyword-t (1 before, 1 after)

C'est tout. Une couple d'instructions `switch` imbriquées. Non seulement ce code est <span name="short">court</span>, mais il est très, très rapide. Il fait le montant minimum de travail requis pour détecter un mot-clé, et se barre dès qu'il peut dire que l'identifiant ne sera pas un réservé.

Et avec ça, notre scanner est complet.

<aside name="short">

Nous tombons parfois dans le piège de penser que la performance vient de structures de données compliquées, de couches de cache, et d'autres optimisations fantaisistes. Mais, bien des fois, tout ce qui est requis est de faire moins de travail, et je trouve souvent qu'écrire le code le plus simple que je peux est suffisant pour accomplir cela.

</aside>

<div class="challenges">

## Défis

1.  Beaucoup de langages plus récents supportent l'[**interpolation de chaîne**][interp]. À l'intérieur d'un littéral de chaîne, vous avez une sorte de délimiteurs spéciaux -- le plus communément `${` au début et `}` à la fin. Entre ces délimiteurs, n'importe quelle expression peut apparaître. Quand le littéral de chaîne est exécuté, l'expression intérieure est évaluée, convertie en une chaîne, et ensuite fusionnée avec le littéral de chaîne environnant.

    Par exemple, si Lox supportait l'interpolation de chaîne, alors ceci...

    ```lox
    var drink = "Tea";
    var steep = 4;
    var cool = 2;
    print "${drink} will be ready in ${steep + cool} minutes.";
    ```

    ...imprimerait :

    ```text
    Tea will be ready in 6 minutes.
    ```

    Quels types de token définiriez-vous pour implémenter un scanner pour l'interpolation de chaîne ? Quelle séquence de tokens émettriez-vous pour le littéral de chaîne ci-dessus ?

    Quels tokens émettriez-vous pour :

    ```text
    "Nested ${"interpolation?! Are you ${"mad?!"}"}"
    ```

    Considérez de regarder d'autres implémentations de langage qui supportent l'interpolation pour voir comment elles la gèrent.

2.  Plusieurs langages utilisent des chevrons pour les génériques et ont aussi un opérateur de décalage à droite `>>`. Cela a mené à un problème classique dans les premières versions de C++ :

    ```c++
    vector<vector<string>> nestedVectors;
    ```

    Cela produirait une erreur de compilation parce que le `>>` était lexé en un seul token de décalage à droite, pas deux tokens `>`. Les utilisateurs étaient forcés d'éviter cela en mettant un espace entre les chevrons fermants.

    Les versions ultérieures de C++ sont plus intelligentes et peuvent gérer le code ci-dessus. Java et C# n'ont jamais eu le problème. Comment ces langages spécifient-ils et implémentent-ils cela ?

3.  Beaucoup de langages, particulièrement plus tard dans leur évolution, définissent des "mots-clés contextuels". Ce sont des identifiants qui agissent comme des mots réservés dans certains contextes mais peuvent être des identifiants normaux définis par l'utilisateur dans d'autres.

    Par exemple, `await` est un mot-clé à l'intérieur d'une méthode `async` en C#, mais dans d'autres méthodes, vous pouvez utiliser `await` comme votre propre identifiant.

    Nommez quelques mots-clés contextuels d'autres langages, et le contexte où ils sont significatifs. Quels sont les pour et les contre d'avoir des mots-clés contextuels ? Comment les implémenteriez-vous dans le front end de votre langage si vous en aviez besoin ?

[interp]: https://en.wikipedia.org/wiki/String_interpolation

</div>
