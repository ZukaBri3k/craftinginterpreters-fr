> Hash, x. Il n'y a pas de définition pour ce mot -- personne ne sait ce que le hachage est.
>
> <cite>Ambrose Bierce, <em>The Unabridged Devil's Dictionary</em></cite>

Avant que nous puissions ajouter des variables à notre machine virtuelle bourgeonnante, nous avons besoin d'un moyen de chercher une valeur étant donné un nom de variable. Plus tard, quand nous ajouterons les classes, nous aurons aussi besoin d'un moyen de stocker des champs sur les instances. La structure de données parfaite pour ces problèmes et d'autres est une table de hachage.

Vous savez probablement déjà ce qu'est une table de hachage, même si vous ne la connaissez pas sous ce nom. Si vous êtes un programmeur Java, vous les appelez "HashMaps". Les utilisateurs C# et Python les appellent "dictionnaires". En C++, c'est une "unordered map". Les "objets" en JavaScript et les "tables" en Lua sont des tables de hachage sous le capot, ce qui est ce qui leur donne leur flexibilité.

Une table de hachage, peu importe comment votre langage l'appelle, associe un ensemble de **clés** avec un ensemble de **valeurs**. Chaque paire clé/valeur est une **entrée** dans la table. Étant donné une clé, vous pouvez chercher sa valeur correspondante. Vous pouvez ajouter de nouvelles paires clé/valeur et supprimer des entrées par clé. Si vous ajoutez une nouvelle valeur pour une clé existante, elle remplace l'entrée précédente.

Les tables de hachage apparaissent dans tellement de langages parce qu'elles sont incroyablement puissantes. Beaucoup de ce pouvoir vient d'une métrique : étant donné une clé, une table de hachage renvoie la valeur correspondante en <span name="constant">temps constant</span>, _indépendamment de combien de clés sont dans la table de hachage_.

<aside name="constant">

Plus spécifiquement, le temps de recherche dans le _cas moyen_ est constant. La performance dans le pire cas peut être, eh bien, pire. En pratique, il est facile d'éviter le comportement dégénéré et de rester sur le chemin heureux.

</aside>

C'est assez remarquable quand vous y pensez. Imaginez que vous avez une grosse pile de cartes de visite et que je vous demande de trouver une certaine personne. Plus la pile est grosse, plus ça prendra de temps. Même si la pile est joliment triée et que vous avez la dextérité manuelle pour faire une recherche binaire à la main, vous parlez toujours de _O(log n)_. Mais avec une <span name="rolodex">table de hachage</span>, cela prend le même temps pour trouver cette carte de visite quand la pile a dix cartes que quand elle en a un million.

<aside name="rolodex">

Fourrez toutes ces cartes dans un Rolodex -- est-ce que quelqu'un se souvient même de ces choses ? -- avec des diviseurs pour chaque lettre, et vous améliorez votre vitesse dramatiquement. Comme nous le verrons, ce n'est pas trop loin du truc qu'une table de hachage utilise.

</aside>

## Un Tableau de Seaux

Une table de hachage complète et rapide a une couple de parties mobiles. Je les introduirai une à la fois en travaillant à travers une couple de problèmes jouets et leurs solutions. Éventuellement, nous construirons jusqu'à une structure de données qui peut associer n'importe quel ensemble de noms avec leurs valeurs.

Pour l'instant, imaginez si Lox était _beaucoup_ plus restreint dans les noms de variable. Et si le nom d'une variable pouvait seulement être une <span name="basic">lettre unique</span> minuscule. Comment pourrions-nous représenter très efficacement un ensemble de noms de variable et leurs valeurs ?

<aside name="basic">

Cette limitation n'est pas _trop_ tirée par les cheveux. Les versions initiales de BASIC venant de Dartmouth permettaient aux noms de variable d'être seulement une lettre unique suivie par un chiffre optionnel.

</aside>

Avec seulement 26 variables possibles (27 si vous considérez le trait de soulignement comme une "lettre", je suppose), la réponse est facile. Déclarez un tableau de taille fixe avec 26 éléments. Nous suivrons la tradition et appellerons chaque élément un **seau**. Chacun représente une variable avec `a` commençant à l'index zéro. S'il y a une valeur dans le tableau à l'index d'une certaine lettre, alors cette clé est présente avec cette valeur. Sinon, le seau est vide et cette paire clé/valeur n'est pas dans la structure de données.

<aside name="bucket">

<img src="image/hash-tables/bucket-array.png" alt="Une rangée de seaux, chacun étiqueté avec une lettre de l'alphabet." />

</aside>

L'utilisation mémoire est super -- juste un unique <span name="bucket">tableau</span> de taille raisonnable. Il y a un peu de gaspillage venant des seaux vides, mais ce n'est pas énorme. Il n'y a pas de surcharge pour les pointeurs de nœud, le remplissage, ou d'autres trucs que vous obtiendriez avec quelque chose comme une liste chaînée ou un arbre.

La performance est encore meilleure. Étant donné un nom de variable -- son caractère -- vous pouvez soustraire la valeur ASCII de `a` et utiliser le résultat pour indexer directement dans le tableau. Ensuite vous pouvez soit chercher la valeur existante ou stocker une nouvelle valeur directement dans cet emplacement. Ça ne devient pas beaucoup plus rapide que ça.

C'est une sorte de notre structure de données idéale Platonicienne. Rapide comme l'éclair, simple à mourir, et compacte en mémoire. Alors que nous ajoutons le support pour des clés plus complexes, nous devrons faire quelques concessions, mais c'est ce que nous visons. Même une fois que vous ajoutez les fonctions de hachage, le redimensionnement dynamique, et la résolution de collision, c'est toujours le cœur de chaque table de hachage là-dehors -- un tableau contigu de seaux dans lequel vous indexez directement.

### Facteur de charge et clés enveloppées

Confiner Lox à des variables d'une seule lettre rendrait notre travail d'implémenteurs plus facile, mais ce n'est probablement pas amusant de programmer dans un langage qui vous donne seulement 26 emplacements de stockage. Et si nous le relâchions un peu et permettions des variables jusqu'à <span name="six">huit</span> caractères de long ?

<aside name="six">

Encore une fois, cette restriction n'est pas si folle. Les premiers éditeurs de liens pour C traitaient seulement les six premiers caractères des identifiants externes comme significatifs. Tout après cela était ignoré. Si vous vous êtes jamais demandé pourquoi la bibliothèque standard C est si éprise d'abréviation -- je vous regarde, `strncmp()` -- il s'avère que n'était pas entièrement à cause des petits écrans (ou télétypes !) de l'époque.

</aside>

C'est assez petit pour que nous puissions empaqueter tous les huit caractères dans un entier de 64 bits et tourner facilement la chaîne en un nombre. Nous pouvons ensuite l'utiliser comme un index de tableau. Ou, au moins, nous pourrions si nous pouvions d'une manière ou d'une autre allouer un tableau de 295 148 _pétaoctets_. La mémoire est devenue moins chère avec le temps, mais pas tout à fait _aussi_ bon marché. Même si nous pouvions faire un tableau aussi gros, ce serait atrocement gaspilleur. Presque chaque seau serait vide à moins que les utilisateurs commencent à écrire des programmes Lox bien plus gros que nous l'avons anticipé.

Même si nos clés de variable couvrent la plage numérique complète de 64 bits, nous n'avons clairement pas besoin d'un tableau aussi large. Au lieu de cela, nous allouons un tableau avec plus d'assez de capacité pour les entrées dont nous avons besoin, mais pas déraisonnablement large. Nous mappons les clés complètes de 64 bits vers cette plage plus petite en prenant la valeur modulo la taille du tableau. Faire cela plie essentiellement la plage numérique plus large sur elle-même jusqu'à ce qu'elle tienne dans la plage plus petite des éléments du tableau.

Par exemple, disons que nous voulons stocker "bagel". Nous allouons un tableau avec huit éléments, plein assez pour le stocker et plus plus tard. Nous traitons la chaîne clé comme un entier de 64 bits. Sur une machine little-endian comme Intel, empaqueter ces caractères dans un mot de 64 bits met la première lettre, "b" (valeur ASCII 98), dans l'octet de poids faible. Nous prenons cet entier modulo la taille du tableau (<span name="power-of-two">8</span>) pour le faire tenir dans les bornes et obtenir un index de seau, 2. Ensuite nous stockons la valeur là comme d'habitude.

<aside name="power-of-two">

J'utilise des puissances de deux pour les tailles de tableau ici, mais elles n'ont pas besoin de l'être. Certains styles de tables de hachage fonctionnent mieux avec des puissances de deux, incluant celle que nous construirons dans ce livre. D'autres préfèrent des tailles de tableau nombres premiers ou ont d'autres règles.

</aside>

Utiliser la taille du tableau comme un module nous laisse mapper la plage numérique de la clé pour tenir dans un tableau de n'importe quelle taille. Nous pouvons ainsi contrôler le nombre de seaux indépendamment de la plage de clé. Cela résout notre problème de gaspillage, mais en introduit un nouveau. Deux variables quelconques dont le nombre clé a le même reste quand divisé par la taille du tableau finiront dans le même seau. Les clés peuvent entrer en **collision**. Par exemple, si nous essayons d'ajouter "jam", il finit aussi dans le seau 2.

<img src="image/hash-tables/collision.png" alt="'Bagel' et 'jam' finissent tous deux dans l'index de seau 2." />

Nous avons un peu de contrôle sur cela en réglant la taille du tableau. Plus le tableau est grand, moins il y a d'index qui sont mappés vers le même seau et moins il y a de collisions qui sont susceptibles de se produire. Les implémenteurs de table de hachage suivent cette probabilité de collision en mesurant le **facteur de charge** de la table. Il est défini comme le nombre d'entrées divisé par le nombre de seaux. Donc une table de hachage avec cinq entrées et un tableau de 16 éléments a un facteur de charge de 0,3125. Plus le facteur de charge est élevé, plus la chance de collisions est grande.

Une façon dont nous atténuons les collisions est en redimensionnant le tableau. Juste comme les tableaux dynamiques que nous avons implémentés plus tôt, nous réallouons et grandissons le tableau de la table de hachage alors qu'il se remplit. Contrairement à un tableau dynamique régulier, cependant, nous n'attendrons pas jusqu'à ce que le tableau soit _plein_. Au lieu de cela, nous choisissons un facteur de charge désiré et grandissons le tableau quand il dépasse cela.

## Résolution de Collision

Même avec un facteur de charge très bas, les collisions peuvent toujours se produire. Le [_paradoxe des anniversaires_][birthday] nous dit que comme le nombre d'entrées dans la table de hachage augmente, la chance de collision augmente très rapidement. Nous pouvons choisir une grande taille de tableau pour réduire cela, mais c'est un jeu perdant. Disons que nous voulions stocker une centaine d'éléments dans une table de hachage. Pour garder la chance de collision en dessous d'un toujours-assez-haut 10%, nous avons besoin d'un tableau avec au moins 47 015 éléments. Pour obtenir la chance en dessous de 1% exige un tableau avec 492 555 éléments, plus de 4 000 seaux vides pour chaque utilisé.

[birthday]: https://en.wikipedia.org/wiki/Birthday_problem

Un facteur de charge bas peut rendre les collisions <span name="pigeon">plus rares</span>, mais le [_principe des tiroirs_][pigeon] nous dit que nous ne pouvons jamais les éliminer entièrement. Si vous avez cinq pigeons de compagnie et quatre trous pour les mettre dedans, au moins un trou va finir avec plus d'un pigeon. Avec 18 446 744 073 709 551 616 noms de variable différents, n'importe quel tableau de taille raisonnable peut potentiellement finir avec de multiples clés dans le même seau.

[pigeon]: https://en.wikipedia.org/wiki/Pigeonhole_principle

Ainsi nous devons toujours gérer les collisions gracieusement quand elles se produisent. Les utilisateurs n'aiment pas quand leur langage de programmation peut chercher des variables correctement seulement la _plupart_ du temps.

<aside name="pigeon">

Mettez ces deux règles mathématiques aux noms drôles ensemble et vous obtenez cette observation : Prenez un nichoir contenant 365 trous de pigeon, et utilisez l'anniversaire de chaque pigeon pour l'assigner à un trou. Vous aurez besoin seulement d'environ 26 pigeons choisis aléatoirement avant que vous obteniez une chance supérieure à 50% de deux pigeons dans la même boîte.

<img src="image/hash-tables/pigeons.png" alt="Deux pigeons dans le même trou." />

</aside>

### Chaînage séparé

Les techniques pour résoudre les collisions tombent dans deux larges catégories. La première est le **chaînage séparé**. Au lieu que chaque seau contienne une entrée unique, nous le laissons en contenir une collection. Dans l'implémentation classique, chaque seau pointe vers une liste chaînée d'entrées. Pour chercher une entrée, vous trouvez son seau et ensuite marchez la liste jusqu'à ce que vous trouviez une entrée avec la clé correspondante.

<img src="image/hash-tables/chaining.png" alt="Un tableau avec huit seaux. Le seau 2 lie vers une chaîne de deux nœuds. Le seau 5 lie vers un nœud unique." />

Dans les cas catastrophiquement mauvais où chaque entrée entre en collision dans le même seau, la structure de données se dégrade en une liste chaînée non triée unique avec une recherche en _O(n)_. En pratique, il est facile d'éviter cela en contrôlant le facteur de charge et comment les entrées sont éparpillées à travers les seaux. Dans les tables de hachage à chaînage séparé typiques, il est rare pour un seau d'avoir plus d'une ou deux entrées.

Le chaînage séparé est conceptuellement simple -- c'est littéralement un tableau de listes chaînées. La plupart des opérations sont directes à implémenter, même la suppression qui, comme nous le verrons, peut être une douleur. Mais ce n'est pas un bon ajustement pour les CPUs modernes. Il a beaucoup de surcharge venant des pointeurs et tend à éparpiller de petits <span name="node">nœuds</span> de liste chaînée autour en mémoire ce qui n'est pas génial pour l'utilisation du cache.

<aside name="node">

Il y a quelques trucs pour optimiser cela. Beaucoup d'implémentations stockent la première entrée juste dans le seau pour que dans le cas commun où il n'y en a qu'une, aucune indirection de pointeur supplémentaire n'est nécessaire. Vous pouvez aussi faire que chaque nœud de liste chaînée stocke quelques entrées pour réduire la surcharge de pointeur.

</aside>

### Adressage ouvert

L'autre technique est <span name="open">appelée</span> **adressage ouvert** ou (confusément) **hachage fermé**. Avec cette technique, toutes les entrées vivent directement dans le tableau de seaux, avec une entrée par seau. Si deux entrées entrent en collision dans le même seau, nous trouvons un scau vide différent à utiliser au lieu de cela.

<aside name="open">

C'est appelé "ouvert" parce que l'entrée peut finir à une adresse (seau) en dehors de celle préférée. C'est appelé hachage "fermé" parce que toutes les entrées restent à l'intérieur du tableau de seaux.

</aside>

Stocker toutes les entrées dans un tableau unique, gros, contigu est génial pour garder la représentation mémoire simple et rapide. Mais cela rend toutes les opérations sur la table de hachage plus complexes. Quand on insère une entrée, son seau peut être plein, nous envoyant regarder un autre seau. Ce seau lui-même peut être occupé et ainsi de suite. Ce processus de trouver un seau disponible est appelé **sondage** (probing), et l'ordre dans lequel vous examinez les seaux est une **séquence de sondage**.

Il y a un <span name="probe">nombre</span> d'algorithmes pour déterminer quels seaux sonder et comment décider quelle entrée va dans quel seau. Il y a eu une tonne de recherche ici parce que même de légers ajustements peuvent avoir un grand impact sur la performance. Et, sur une structure de données aussi lourdement utilisée que les tables de hachage, cet impact de performance touche un très grand nombre de programmes du monde réel à travers une plage de capacités matérielles.

<aside name="probe">

Si vous aimeriez en apprendre plus (et vous devriez, parce que certains de ceux-là sont vraiment cool), regardez dans "double hachage", "hachage coucou", "hachage Robin des Bois", et tout ce à quoi ceux-là vous mènent.

</aside>

Comme d'habitude dans ce livre, nous choisirons le plus simple qui fait le travail efficacement. C'est le bon vieux **sondage linéaire**. Quand on cherche une entrée, nous regardons dans le premier seau auquel sa clé mappe. S'il n'est pas là, nous regardons dans l'élément juste suivant dans le tableau, et ainsi de suite. Si nous atteignons la fin, nous enveloppons en retour au début.

La bonne chose à propos du sondage linéaire est qu'il est ami du cache. Puisque vous marchez le tableau directement dans l'ordre de la mémoire, il garde les lignes de cache du CPU pleines et heureuses. La mauvaise chose est qu'il est sujet au **regroupement** (clustering). Si vous avez beaucoup d'entrées avec des valeurs de clé numériquement similaires, vous pouvez finir avec beaucoup de seaux entrant en collision, débordant juste les uns à côté des autres.

Comparé au chaînage séparé, l'adressage ouvert peut être plus dur à comprendre. Je pense à l'adressage ouvert comme similaire au chaînage séparé sauf que la "liste" des nœuds est enfilée à travers le tableau de seaux lui-même. Au lieu de stocker les liens entre eux dans des pointeurs, les connexions sont calculées implicitement par l'ordre que vous regardez à travers les seaux.

La partie délicate est que plus d'une de ces listes implicites peuvent être entrelacées ensemble. Marchons à travers un exemple qui couvre tous les cas intéressants. Nous ignorerons les valeurs pour l'instant et nous inquiéterons juste d'un ensemble de clés. Nous commençons avec un tableau vide de 8 seaux.

<img src="image/hash-tables/insert-1.png" alt="Un tableau avec huit seaux vides." class="wide" />

Nous décidons d'insérer "bagel". La première lettre, "b" (valeur ASCII 98), modulo la taille du tableau (8) le met dans le seau 2.

<img src="image/hash-tables/insert-2.png" alt="Bagel va dans le seau 2." class="wide" />

Ensuite, nous insérons "jam". Cela veut aussi aller dans le seau 2 (106 mod 8 = 2), mais ce seau est pris. Nous continuons de sonder vers le seau suivant. Il est vide, donc nous le mettons là.

<img src="image/hash-tables/insert-3.png" alt="Jam va dans le seau 3, puisque 2 est plein." class="wide" />

Nous insérons "fruit", qui atterrit joyeusement dans le seau 6.

<img src="image/hash-tables/insert-4.png" alt="Fruit va dans le seau 6." class="wide" />

De même, "migas" peut aller dans son seau préféré 5.

<img src="image/hash-tables/insert-5.png" alt="Migas va dans le seau 5." class="wide" />

Quand nous essayons d'insérer "eggs", il veut aussi être dans le seau 5. C'est plein, donc nous sautons à 6. Le seau 6 est aussi plein. Notez que l'entrée dedans n'est _pas_ partie de la même séquence de sondage. "Fruit" est dans son seau préféré, 6. Donc les séquences 5 et 6 sont entrées en collision et sont entrelacées. Nous sautons par-dessus cela et mettons finalement "eggs" dans le seau 7.

<img src="image/hash-tables/insert-6.png" alt="Eggs va dans le seau 7 parce que 5 et 6 sont pleins." class="wide" />

Nous rencontrons un problème similaire avec "nuts". Il ne peut pas atterrir dans 6 comme il le veut. Ni ne peut-il aller dans 7. Donc nous continuons d'aller. Mais nous avons atteint la fin du tableau, donc nous enveloppons en retour à 0 et le mettons là.

<img src="image/hash-tables/insert-7.png" alt="Nuts enveloppe autour au seau 0 parce que 6 et 7 sont pleins." class="wide" />

En pratique, l'entrelacement s'avère ne pas être tellement un problème. Même dans le chaînage séparé, nous avons besoin de marcher la liste pour vérifier la clé de chaque entrée parce que de multiples clés peuvent réduire au même seau. Avec l'adressage ouvert, nous avons besoin de faire cette même vérification, et cela couvre aussi le cas où vous marchez par-dessus des entrées qui "appartiennent" à un seau original différent.

## Fonctions de Hachage

Nous pouvons maintenant nous construire une table raisonnablement efficace pour stocker des noms de variable jusqu'à huit caractères de long, mais cette limitation est toujours ennuyeuse. Afin de relâcher la dernière contrainte, nous avons besoin d'un moyen de prendre une chaîne de n'importe quelle longueur et de la convertir en un entier de taille fixe.

Finalement, nous arrivons à la partie "hachage" de "table de hachage". Une **fonction de hachage** prend un plus gros blob de données et le "hache" pour produire un entier de taille fixe **code de hachage** dont la valeur dépend de tous les bits des données originales. Une <span name="crypto">bonne</span> fonction de hachage a trois buts principaux :

<aside name="crypto">

Les fonctions de hachage sont aussi utilisées pour la cryptographie. Dans ce domaine, "bonne" a une définition _bien_ plus stricte pour éviter d'exposer des détails à propos des données étant hachées. Nous, heureusement, n'avons pas besoin de nous inquiéter à propos de ces préoccupations pour ce livre.

</aside>

- **Elle doit être _déterministe_.** La même entrée doit toujours hacher vers le même nombre. Si la même variable finit dans différents seaux à différents points dans le temps, ça va devenir vraiment dur de la trouver.

- **Elle doit être _uniforme_.** Étant donné un ensemble typique d'entrées, elle devrait produire une plage large et distribuée également de nombres de sortie, avec aussi peu d'amas ou de motifs que possible. Nous voulons qu'elle <span name="scatter">éparpille</span> les valeurs à travers la plage numérique entière pour minimiser les collisions et le regroupement.

- **Elle doit être _rapide_.** Chaque opération sur la table de hachage nous demande de hacher la clé d'abord. Si le hachage est lent, cela peut potentiellement annuler la vitesse du stockage tableau sous-jacent.

<aside name="scatter">

Un des noms originaux pour une table de hachage était "table d'éparpillement" (scatter table) parce qu'elle prend les entrées et les éparpille à travers le tableau. Le mot "hachage" est venu de l'idée qu'une fonction de hachage prend les données d'entrée, les coupe, et jette tout ensemble dans une pile pour arriver avec un nombre unique depuis tous ces bits.

</aside>

Il y a une véritable pile de fonctions de hachage là-dehors. Certaines sont vieilles et optimisées pour des architectures que personne n'utilise plus. Certaines sont conçues pour être rapides, d'autres cryptographiquement sûres. Certaines tirent avantage des instructions vectorielles et des tailles de cache pour des puces spécifiques, d'autres visent à maximiser la portabilité.

Il y a des gens là-dehors pour qui concevoir et évaluer des fonctions de hachage est, genre, leur _truc_. Je les admire, mais je ne suis pas assez astucieux mathématiquement pour en _être_ un. Donc pour clox, j'ai choisi une fonction de hachage simple, bien usée appelée [FNV-1a][] qui m'a bien servi au fil des années. Considérez d'<span name="thing">essayer</span> différentes autres dans votre code et voyez si elles font une différence.

[fnv-1a]: http://www.isthe.com/chongo/tech/comp/fnv/

<aside name="thing">

Qui sait, peut-être que les fonctions de hachage pourraient s'avérer être votre truc aussi ?

</aside>

OK, c'est un parcours rapide de seaux, facteurs de charge, adressage ouvert, résolution de collision, et fonctions de hachage. C'est terriblement beaucoup de texte et pas beaucoup de vrai code. Ne vous inquiétez pas si cela semble encore vague. Une fois que nous aurons fini de coder ça, tout s'emboîtera en place.

## Construire une Table de Hachage

La grande chose à propos des tables de hachage comparé à d'autres techniques classiques comme les arbres de recherche équilibrés est que la structure de données réelle est si simple. La nôtre va dans un nouveau module.

^code table-h

Une table de hachage est un tableau d'entrées. Comme dans notre tableau dynamique plus tôt, nous gardons une trace à la fois de la taille allouée du tableau (`capacity`) et du nombre de paires clé/valeur actuellement stockées dedans (`count`). Le ratio de compte sur capacité est exactement le facteur de charge de la table de hachage.

Chaque entrée est une de celles-ci :

^code entry (1 before, 2 after)

C'est une simple paire clé/valeur. Puisque la clé est toujours une <span name="string">chaîne</span>, nous stockons le pointeur ObjString directement au lieu de l'envelopper dans une Value. C'est un peu plus rapide et plus petit de cette façon.

<aside name="string">

Dans clox, nous avons seulement besoin de supporter des clés qui sont des chaînes. Gérer d'autres types de clés n'ajoute pas beaucoup de complexité. Tant que vous pouvez comparer deux objets pour l'égalité et les réduire à des séquences de bits, il est facile de les utiliser comme clés de hachage.

</aside>

Pour créer une nouvelle table de hachage vide, nous déclarons une fonction semblable à un constructeur.

^code init-table-h (2 before, 2 after)

Nous avons besoin d'un nouveau fichier d'implémentation pour définir cela. Pendant que nous y sommes, sortons tous les includes embêtants du chemin.

^code table-c

Comme dans notre tableau de valeurs dynamique, une table de hachage commence initialement avec une capacité zéro et un tableau `NULL`. Nous n'allouons rien jusqu'à ce que ce soit nécessaire. En supposant que nous allouons éventuellement quelque chose, nous avons besoin d'être capables de le libérer aussi.

^code free-table-h (1 before, 2 after)

Et sa glorieuse implémentation :

^code free-table

Encore une fois, cela ressemble juste à un tableau dynamique. En fait, vous pouvez penser à une table de hachage comme basiquement un tableau dynamique avec une politique vraiment étrange pour insérer des éléments. Nous n'avons pas besoin de vérifier pour `NULL` ici puisque `FREE_ARRAY()` gère déjà cela gracieusement.

### Hacher les chaînes

Avant que nous puissions commencer à mettre des entrées dans la table, nous avons besoin de, eh bien, les hacher. Pour assurer que les entrées soient distribuées uniformément à travers le tableau, nous voulons une bonne fonction de hachage qui regarde tous les bits de la chaîne clé. Si elle regardait, disons, seulement les quelques premiers caractères, alors une série de chaînes qui partageaient toutes le même préfixe finiraient par entrer en collision dans le même seau.

D'un autre côté, marcher la chaîne entière pour calculer le hachage est assez lent. Nous perdrions une partie du bénéfice de performance de la table de hachage si nous devions marcher la chaîne chaque fois que nous cherchions une clé dans la table. Donc nous ferons la chose évidente : le cacher.

Là-bas dans le module "object" dans ObjString, nous ajoutons :

^code obj-string-hash (1 before, 1 after)

Chaque ObjString stocke le code de hachage pour sa chaîne. Puisque les chaînes sont immuables dans Lox, nous pouvons calculer le code de hachage une fois au départ et être certain qu'il ne sera jamais invalidé. Le cacher avec empressement a une sorte de sens : allouer la chaîne et copier ses caractères par-dessus est déjà une opération en _O(n)_, donc c'est un bon moment pour faire aussi le calcul en _O(n)_ du hachage de la chaîne.

Chaque fois que nous appelons la fonction interne pour allouer une chaîne, nous passons son code de hachage.

^code allocate-string (1 after)

Cette fonction stocke simplement le hachage dans la struct.

^code allocate-store-hash (1 before, 2 after)

Le fun se passe là-bas chez les appelants. `allocateString()` est appelée depuis deux endroits : la fonction qui copie une chaîne et celle qui prend la propriété d'une chaîne allouée dynamiquement existante. Nous commencerons avec la première.

^code copy-string-hash (1 before, 1 after)

Pas de magie ici. Nous calculons le code de hachage et ensuite le passons.

^code copy-string-allocate (2 before, 1 after)

L'autre fonction chaîne est similaire.

^code take-string-hash (1 before, 1 after)

Le code intéressant est ici :

^code hash-string

C'est la vraie fonction de hachage bona fide dans clox. L'algorithme est appelé "FNV-1a", et est la fonction de hachage décente la plus courte que je connaisse. La brièveté est certainement une vertu dans un livre qui vise à vous montrer chaque ligne de code.

L'idée de base est assez simple, et beaucoup de fonctions de hachage suivent le même modèle. Vous commencez avec une valeur de hachage initiale, habituellement une constante avec certaines propriétés mathématiques choisies soigneusement. Ensuite vous marchez les données à hacher. Pour chaque octet (ou parfois mot), vous mélangez les bits dans la valeur de hachage d'une manière ou d'une autre, et ensuite brouillez les bits résultants un peu.

Ce que cela signifie de "mélanger" et "brouiller" peut devenir assez sophistiqué. Ultimement, cependant, le but de base est l'_uniformité_ -- nous voulons que les valeurs de hachage résultantes soient aussi largement éparpillées autour de la plage numérique que possible pour éviter les collisions et le regroupement.

### Insérer des entrées

Maintenant que les objets chaîne connaissent leur code de hachage, nous pouvons commencer à les mettre dans des tables de hachage.

^code table-set-h (1 before, 2 after)

Cette fonction ajoute la paire clé/valeur donnée à la table de hachage donnée. Si une entrée pour cette clé est déjà présente, la nouvelle valeur écrase l'ancienne valeur. La fonction renvoie `true` si une nouvelle entrée a été ajoutée. Voici l'implémentation :

^code table-set

La plupart de la logique intéressante est dans `findEntry()` à laquelle nous arriverons bientôt. Le travail de cette fonction est de prendre une clé et de déterminer dans quel seau dans le tableau elle devrait aller. Elle renvoie un pointeur vers ce seau -- l'adresse de l'Entry dans le tableau.

Une fois que nous avons un seau, insérer est direct. Nous mettons à jour la taille de la table de hachage, prenant soin de ne pas augmenter le compte si nous avons écrasé la valeur pour une clé déjà présente. Ensuite nous copions la clé et la valeur dans les champs correspondants dans l'Entry.

Nous manquons un petit quelque chose ici, cependant. Nous n'avons pas en fait alloué le tableau d'Entry encore. Oups ! Avant que nous puissions insérer quoi que ce soit, nous avons besoin de nous assurer que nous avons un tableau, et qu'il est assez grand.

^code table-set-grow (1 before, 1 after)

C'est similaire au code que nous avons écrit il y a un moment pour grandir un tableau dynamique. Si nous n'avons pas assez de capacité pour insérer un élément, nous réallouons et grandissons le tableau. La macro `GROW_CAPACITY()` prend une capacité existante et la grandit par un multiple pour assurer que nous obtenons une performance constante amortie sur une série d'insertions.

La différence intéressante ici est cette constante `TABLE_MAX_LOAD`.

^code max-load (2 before, 1 after)

C'est comment nous gérons le facteur de <span name="75">charge</span> de la table. Nous ne grandissons pas quand la capacité est complètement pleine. Au lieu de cela, nous grandissons le tableau avant cela, quand le tableau devient au moins 75% plein.

<aside name="75">

Le facteur de charge max idéal varie basé sur la fonction de hachage, la stratégie de gestion de collision, et les ensembles de clés typiques que vous verrez. Puisque un langage jouet comme Lox n'a pas d'ensembles de données "monde réel", il est dur d'optimiser cela, et j'ai choisi 75% quelque peu arbitrairement. Quand vous construisez vos propres tables de hachage, benchmarkez et réglez ceci.

</aside>

Nous arriverons à l'implémentation de `adjustCapacity()` bientôt. D'abord, regardons cette fonction `findEntry()` à propos de laquelle vous vous êtes posé des questions.

^code find-entry

Cette fonction est le vrai cœur de la table de hachage. Elle est responsable de prendre une clé et un tableau de seaux, et de déterminer dans quel seau l'entrée appartient. Cette fonction est aussi là où le sondage linéaire et la gestion de collision entrent en jeu. Nous utiliserons `findEntry()` à la fois pour chercher des entrées existantes dans la table de hachage et pour décider où en insérer de nouvelles.

Pour tout cela, il n'y a pas grand-chose. D'abord, nous utilisons le modulo pour mapper le code de hachage de la clé vers un index à l'intérieur des bornes du tableau. Cela nous donne un index de seau où, idéalement, nous serons capables de trouver ou placer l'entrée.

Il y a quelques cas à vérifier :

- Si la clé pour l'Entry à cet index de tableau est `NULL`, alors le seau est vide. Si nous utilisons `findEntry()` pour chercher quelque chose dans la table de hachage, cela signifie que ce n'est pas là. Si nous l'utilisons pour insérer, cela signifie que nous avons trouvé un endroit pour ajouter la nouvelle entrée.

- Si la clé dans le seau est <span name="equal">égale</span> à la clé que nous cherchons, alors cette clé est déjà présente dans la table. Si nous faisons une recherche, c'est bon -- nous avons trouvé la clé que nous cherchons. Si nous faisons une insertion, cela signifie que nous remplacerons la valeur pour cette clé au lieu d'ajouter une nouvelle entrée.

<aside name="equal">

On dirait que nous utilisons `==` pour voir si deux chaînes sont égales. Cela ne marche pas, n'est-ce pas ? Il pourrait y avoir deux copies de la même chaîne à différents endroits en mémoire. Ne craignez rien, lecteur astucieux. Nous résoudrons cela plus loin. Et, assez étrangement, c'est une table de hachage qui fournit l'outil dont nous avons besoin.

</aside>

- Sinon, le seau a une entrée dedans, mais avec une clé différente. C'est une collision. Dans ce cas, nous commençons à sonder. C'est ce que cette boucle `for` fait. Nous commençons au seau où l'entrée irait idéalement. Si ce seau est vide ou a la même clé, nous avons fini. Sinon, nous avançons à l'élément suivant -- c'est la partie _linéaire_ de "sondage linéaire" -- et vérifions là. Si nous allons au-delà de la fin du tableau, ce second opérateur modulo nous enveloppe en retour au début.

Nous sortons de la boucle quand nous trouvons soit un seau vide ou un seau avec la même clé que celle que nous cherchons. Vous pourriez vous demander à propos d'une boucle infinie. Et si nous entrions en collision avec _chaque_ seau ? Heureusement, cela ne peut pas arriver grâce à notre facteur de charge. Parce que nous grandissons le tableau dès qu'il devient proche d'être plein, nous savons qu'il y aura toujours des seaux vides.

Nous renvoyons directement depuis l'intérieur de la boucle, donnant un pointeur vers l'Entry trouvée pour que l'appelant puisse soit insérer quelque chose dedans ou lire depuis elle. Tout là-bas dans `tableSet()`, la fonction qui a d'abord lancé tout ça, nous stockons la nouvelle entrée dans ce seau retourné et nous avons fini.

### Allouer et redimensionner

Avant que nous puissions mettre des entrées dans la table de hachage, nous avons besoin d'un endroit pour les stocker réellement. Nous avons besoin d'allouer un tableau de seaux. Cela arrive dans cette fonction :

^code table-adjust-capacity

Nous créons un tableau de seaux avec `capacity` entrées. Après que nous ayons alloué le tableau, nous initialisons chaque élément pour être un seau vide et ensuite stockons le tableau (et sa capacité) dans la struct principale de la table de hachage. Ce code est bien pour quand nous insérons la toute première entrée dans la table, et nous exigeons la première allocation du tableau. Mais quoi à propos de quand nous en avons déjà un et que nous avons besoin de le grandir ?

Quand nous faisions un tableau dynamique, nous pouvions juste utiliser `realloc()` et laisser la bibliothèque standard C copier tout par-dessus. Cela ne marche pas pour une table de hachage. Rappelez-vous que pour choisir le seau pour chaque entrée, nous prenons sa clé de hachage _modulo la taille du tableau_. Cela signifie que quand la taille du tableau change, les entrées peuvent finir dans des seaux différents.

Ces nouveaux seaux peuvent avoir de nouvelles collisions que nous avons besoin de gérer. Donc la façon la plus simple de mettre chaque entrée où elle appartient est de reconstruire la table depuis zéro en réinsérant chaque entrée dans le nouveau tableau vide.

^code re-hash (2 before, 2 after)

Nous marchons à travers le vieux tableau du début à la fin. Chaque fois que nous trouvons un seau non vide, nous insérons cette entrée dans le nouveau tableau. Nous utilisons `findEntry()`, passant le _nouveau_ tableau au lieu de celui actuellement stocké dans la Table. (C'est pourquoi `findEntry()` prend un pointeur directement vers un tableau d'Entry et pas la struct `Table` entière. De cette façon, nous pouvons passer le nouveau tableau et la capacité avant que nous ayons stocké ceux-là dans la struct.)

Après que c'est fait, nous pouvons relâcher la mémoire pour le vieux tableau.

^code free-old-array (3 before, 1 after)

Avec cela, nous avons une table de hachage dans laquelle nous pouvons bourrer autant d'entrées que nous voulons. Elle gère l'écrasement de clés existantes et se grandit elle-même au besoin pour maintenir la capacité de charge désirée.

Pendant que nous y sommes, définissons aussi une fonction aide pour copier toutes les entrées d'une table de hachage dans une autre.

^code table-add-all-h (1 before, 2 after)

Nous n'aurons pas besoin de ceci avant bien plus tard quand nous supporterons l'héritage de méthode, mais nous pouvons aussi bien l'implémenter maintenant pendant que nous avons tous les trucs de table de hachage frais dans nos esprits.

^code table-add-all

Il n'y a pas grand-chose à dire à propos de ceci. Elle marche le tableau de seaux de la table de hachage source. Chaque fois qu'elle trouve un seau non vide, elle ajoute l'entrée à la table de hachage destination utilisant la fonction `tableSet()` que nous avons récemment définie.

### Récupérer les valeurs

Maintenant que notre table de hachage contient des trucs, commençons à tirer des choses en retour. Étant donné une clé, nous pouvons chercher la valeur correspondante, s'il y en a une, avec cette fonction :

^code table-get-h (1 before, 1 after)

Vous passez une table et une clé. Si elle trouve une entrée avec cette clé, elle renvoie `true`, sinon elle renvoie `false`. Si l'entrée existe, le paramètre de sortie `value` pointe vers la valeur résultante.

Puisque `findEntry()` fait déjà le travail dur, l'implémentation n'est pas mauvaise.

^code table-get

Si la table est complètement vide, nous ne trouverons définitivement pas l'entrée, donc nous vérifions cela d'abord. Ce n'est pas juste une optimisation -- cela assure aussi que nous n'essayons pas d'accéder au tableau de seaux quand le tableau est `NULL`. Sinon, nous laissons `findEntry()` travailler sa magie. Cela renvoie un pointeur vers un seau. Si le seau est vide, ce que nous détectons en voyant si la clé est `NULL`, alors nous n'avons pas trouvé une Entry avec notre clé. Si `findEntry()` renvoie bien une Entry non vide, alors c'est notre correspondance. Nous prenons la valeur de l'Entry et la copions vers le paramètre de sortie pour que l'appelant puisse l'obtenir. De la tarte.

### Supprimer les entrées

Il y a une opération fondamentale de plus qu'une table de hachage complète a besoin de supporter : supprimer une entrée. Cela semble assez évident, si vous pouvez ajouter des choses, vous devriez être capable de les _dés_-ajouter, pas vrai ? Mais vous seriez surpris combien de tutoriels sur les tables de hachage omettent ça.

J'aurais pu prendre cette route aussi. En fait, nous utilisons la suppression dans clox seulement dans un minuscule cas limite dans la VM. Mais si vous voulez réellement comprendre comment implémenter complètement une table de hachage, cela semble important. Je peux sympathiser avec leur désir de négliger ça. Comme nous le verrons, supprimer d'une table de hachage qui utilise l'adressage <span name="delete">ouvert</span> est délicat.

<aside name="delete">

Avec le chaînage séparé, supprimer est aussi facile que retirer un nœud d'une liste chaînée.

</aside>

Au moins la déclaration est simple.

^code table-delete-h (1 before, 1 after)

L'approche évidente est de refléter l'insertion. Utilisez `findEntry()` pour chercher le seau de l'entrée. Ensuite videz le seau. Fini !

Dans les cas où il n'y a pas de collisions, cela marche très bien. Mais si une collision s'est produite, alors le seau où l'entrée vit peut faire partie d'une ou plus séquences de sondage implicites. Par exemple, voici une table de hachage contenant trois clés toutes avec le même seau préféré, 2 :

<img src="image/hash-tables/delete-1.png" alt="Une table de hachage contenant 'bagel' dans le seau 2, 'biscuit' dans le seau 3, et 'jam' dans le seau 4." />

Rappelez-vous que quand nous marchons une séquence de sondage pour trouver une entrée, nous savons que nous avons atteint la fin d'une séquence et que l'entrée n'est pas présente quand nous touchons un seau vide. C'est comme si la séquence de sondage était une liste d'entrées et une entrée vide termine cette liste.

Si nous supprimons "biscuit" en vidant simplement l'Entry, alors nous cassons cette séquence de sondage au milieu, laissant les entrées traînantes orphelines et inatteignables. Un peu comme retirer un nœud d'une liste chaînée sans relier le pointeur du nœud précédent au suivant.

Si nous essayons plus tard de chercher "jam", nous commencerions à "bagel", arrêterions à la prochaine Entry vide, et ne le trouverions jamais.

<img src="image/hash-tables/delete-2.png" alt="L'entrée 'biscuit' a été supprimée de la table de hachage, cassant la chaîne." />

Pour résoudre cela, la plupart des implémentations utilisent un truc appelé <span name="tombstone">**pierres tombales**</span> (tombstones). Au lieu de vider l'entrée à la suppression, nous la remplaçons par une entrée sentinelle spéciale appelée une "pierre tombale". Quand nous suivons une séquence de sondage pendant une recherche, et que nous touchons une pierre tombale, nous ne la traitons _pas_ comme un emplacement vide et n'arrêtons pas d'itérer. Au lieu de cela, nous continuons d'aller pour que supprimer une entrée ne casse aucune chaîne de collision implicite et que nous puissions toujours trouver les entrées après elle.

<img src="image/hash-tables/delete-3.png" alt="Au lieu de supprimer 'biscuit', il est remplacé par une pierre tombale." />

Le code ressemble à ceci :

^code table-delete

D'abord, nous trouvons le seau contenant l'entrée que nous voulons supprimer. (Si nous ne la trouvons pas, il n'y a rien à supprimer, donc nous abandonnons.) Nous remplaçons l'entrée par une pierre tombale. Dans clox, nous utilisons une clé `NULL` et une valeur `true` pour représenter cela, mais n'importe quelle représentation qui ne peut pas être confondue avec un seau vide ou une entrée valide marche.

<aside name="tombstone">

<img src="image/hash-tables/tombstone.png" alt="Une pierre tombale inscrite 'Ci-gît l'entrée biscuit &rarr; 3.75, partie mais pas supprimée'." />

</aside>

C'est tout ce que nous avons besoin de faire pour supprimer une entrée. Simple et rapide. Mais toutes les autres opérations ont besoin de gérer correctement les pierres tombales aussi. Une pierre tombale est une sorte de "demi" entrée. Elle a certaines des caractéristiques d'une entrée présente, et certaines des caractéristiques d'une vide.

Quand nous suivons une séquence de sondage pendant une recherche, et que nous touchons une pierre tombale, nous la notons et continuons.

^code find-tombstone (2 before, 2 after)

La première fois que nous passons une pierre tombale, nous la stockons dans cette variable locale :

^code find-entry-tombstone (1 before, 1 after)

Si nous atteignons une entrée vraiment vide, alors la clé n'est pas présente. Dans ce cas, si nous avons passé une pierre tombale, nous renvoyons son seau au lieu de celui vide ultérieur. Si nous appelons `findEntry()` afin d'insérer un nœud, cela nous laisse traiter le seau pierre tombale comme vide et le réutiliser pour la nouvelle entrée.

Réutiliser les emplacements pierre tombale automatiquement comme ceci aide à réduire le nombre de pierres tombales gaspillant de l'espace dans le tableau de seaux. Dans les cas d'utilisation typiques où il y a un mélange d'insertions et de suppressions, le nombre de pierres tombales grandit pendant un moment et ensuite tend à se stabiliser.

Même ainsi, il n'y a aucune garantie qu'un grand nombre de suppressions ne causera pas que le tableau soit plein de pierres tombales. Dans le pire des cas, nous pourrions finir avec _aucun_ seau vide. Ce serait mauvais parce que, rappelez-vous, la seule chose empêchant une boucle infinie dans `findEntry()` est la supposition que nous toucherons éventuellement un seau vide.

Donc nous devons être réfléchis sur comment les pierres tombales interagissent avec le facteur de charge de la table et le redimensionnement. La question clé est, quand nous calculons le facteur de charge, devrions-nous traiter les pierres tombales comme des seaux pleins ou vides ?

### Compter les pierres tombales

Si nous traitons les pierres tombales comme des seaux pleins, alors nous pouvons finir avec un tableau plus gros que ce dont nous avons probablement besoin parce qu'il gonfle artificiellement le facteur de charge. Il y a des pierres tombales que nous pourrions réutiliser, mais elles ne sont pas traitées comme inutilisées donc nous finissons par grandir le tableau prématurément.

Mais si nous traitons les pierres tombales comme des seaux vides et ne les incluons _pas_ dans le facteur de charge, alors nous courons le risque de finir avec _aucun_ vrai seau vide pour terminer une recherche. Une boucle infinie est un problème bien pire que quelques emplacements de tableau supplémentaires, donc pour le facteur de charge, nous considérons les pierres tombales comme étant des seaux pleins.

C'est pourquoi nous ne réduisons pas le compte quand nous supprimons une entrée dans le code précédent. Le compte n'est plus le nombre d'entrées dans la table de hachage, c'est le nombre d'entrées plus les pierres tombales. Cela implique que nous incrémentons le compte pendant l'insertion seulement si la nouvelle entrée va dans un seau entièrement vide.

^code set-increment-count (1 before, 2 after)

Si nous remplaçons une pierre tombale par une nouvelle entrée, le seau a déjà été comptabilisé et le compte ne change pas.

Quand nous redimensionnons le tableau, nous allouons un nouveau tableau et réinsérons toutes les entrées existantes dedans. Pendant ce processus, nous ne copions _pas_ les pierres tombales. Elles n'ajoutent aucune valeur puisque nous reconstruisons les séquences de sondage de toute façon, et ralentiraient juste les recherches. Cela signifie que nous avons besoin de recalculer le compte puisqu'il peut changer pendant un redimensionnement. Donc nous le vidons :

^code resize-init-count (2 before, 1 after)

Ensuite chaque fois que nous trouvons une entrée non-pierre tombale, nous l'incrémentons.

^code resize-increment-count (1 before, 1 after)

Cela signifie que quand nous grandissons la capacité, nous pouvons finir avec _moins_ d'entrées dans le tableau résultant plus grand parce que toutes les pierres tombales sont jetées. C'est un peu gaspilleur, mais pas un énorme problème pratique.

Je trouve intéressant que beaucoup du travail pour supporter la suppression d'entrées est dans `findEntry()` et `adjustCapacity()`. La logique de suppression réelle est assez simple et rapide. En pratique, les suppressions tendent à être rares, donc vous vous attendriez à ce qu'une table de hachage fasse autant de travail qu'elle peut dans la fonction de suppression et laisse les autres fonctions tranquilles pour les garder plus rapides. Avec notre approche pierre tombale, les suppressions sont rapides, mais les recherches sont pénalisées.

J'ai fait un peu de benchmarking pour tester cela dans quelques scénarios de suppression différents. J'ai été surpris de découvrir que les pierres tombales finissaient par être plus rapides globalement comparé à faire tout le travail pendant la suppression pour réinsérer les entrées affectées.

Mais si vous y pensez, ce n'est pas que l'approche pierre tombale pousse le travail de supprimer entièrement une entrée vers d'autres opérations, c'est plus qu'elle rend la suppression _paresseuse_. Au début, elle fait le travail minimal pour transformer l'entrée en une pierre tombale. Cela peut causer une pénalité quand des recherches ultérieures doivent sauter par-dessus. Mais cela permet aussi à ce seau pierre tombale d'être réutilisé par une insertion ultérieure aussi. Cette réutilisation est un moyen très efficace d'éviter le coût de réarranger toutes les entrées affectées suivantes. Vous recyclez basiquement un nœud dans la chaîne d'entrées sondées. C'est un truc net.

## Internalisation de Chaîne

Nous avons nous-mêmes une table de hachage qui marche la plupart du temps, bien qu'elle ait un défaut critique en son centre. Aussi, nous ne l'utilisons pour rien encore. Il est temps d'adresser ces deux choses et, dans le processus, d'apprendre une technique classique utilisée par les interpréteurs.

La raison pour laquelle la table de hachage ne marche pas totalement est que quand `findEntry()` vérifie pour voir si une clé existante correspond à celle qu'elle cherche, elle utilise `==` pour comparer deux chaînes pour l'égalité. Cela renvoie vrai seulement si les deux clés sont exactement la même chaîne en mémoire. Deux chaînes séparées avec les mêmes caractères devraient être considérées égales, mais ne le sont pas.

Rappelez-vous, il y a un moment quand nous avons ajouté les chaînes dans le dernier chapitre, nous avons ajouté un [support explicite pour comparer les chaînes caractère-par-caractère][equals] afin d'obtenir une vraie égalité de valeur. Nous pourrions faire cela dans `findEntry()`, mais c'est <span name="hash-collision">lent</span>.

[equals]: chaînes-de-caractères.html#opérations-sur-les-chaînes

<aside name="hash-collision">

En pratique, nous comparerions d'abord les codes de hachage des deux chaînes. Cela détecte rapidement presque toutes les chaînes différentes -- ce ne serait pas une très bonne fonction de hachage si elle ne le faisait pas. Mais quand les deux hachages sont les mêmes, nous devons toujours comparer les caractères pour nous assurer que nous n'avons pas eu de collision de hachage sur des chaînes différentes.

</aside>

Au lieu de cela, nous utiliserons une technique appelée **internalisation de chaîne** (string interning). Le problème central est qu'il est possible d'avoir des chaînes différentes en mémoire avec les mêmes caractères. Celles-ci ont besoin de se comporter comme des valeurs équivalentes même bien qu'elles soient des objets distincts. Elles sont essentiellement des doublons, et nous devons comparer tous leurs octets pour détecter cela.

L'<span name="intern">internalisation de chaîne</span> est un processus de déduplication. Nous créons une collection de chaînes "internalisées". N'importe quelle chaîne dans cette collection est garantie d'être textuellement distincte de toutes les autres. Quand vous internalisez une chaîne, vous cherchez une chaîne correspondante dans la collection. Si trouvée, vous utilisez l'originale. Sinon, la chaîne que vous avez est unique, donc vous l'ajoutez à la collection.

<aside name="intern">

Je devine que "intern" est court pour "internal" (interne). Je pense que l'idée est que le runtime du langage garde sa propre collection "interne" de ces chaînes, alors que d'autres chaînes pourraient être créées par l'utilisateur et flotter autour en mémoire. Quand vous internalisez une chaîne, vous demandez au runtime d'ajouter la chaîne à cette collection interne et de renvoyer un pointeur vers elle.

Les langages varient dans combien d'internalisation de chaîne ils font et comment c'est exposé à l'utilisateur. Lua internalise _toutes_ les chaînes, ce qui est ce que clox fera aussi. Lisp, Scheme, Smalltalk, Ruby et d'autres ont un type semblable à une chaîne séparé appelé "symbole" qui est implicitement internalisé. (C'est pourquoi ils disent que les symboles sont "plus rapides" en Ruby.) Java internalise les chaînes constantes par défaut, et fournit une API pour vous laisser internaliser explicitement n'importe quelle chaîne que vous lui donnez.

</aside>

De cette façon, vous savez que chaque séquence de caractères est représentée par seulement une chaîne en mémoire. Cela rend l'égalité de valeur triviale. Si deux chaînes pointent vers la même adresse en mémoire, elles sont évidemment la même chaîne et doivent être égales. Et, parce que nous savons que les chaînes sont uniques, si deux chaînes pointent vers des adresses différentes, elles doivent être des chaînes distinctes.

Ainsi, l'égalité de pointeur correspond exactement à l'égalité de valeur. Ce qui à son tour signifie que notre `==` existant dans `findEntry()` fait la bonne chose. Ou, au moins, il le fera une fois que nous aurons internalisé toutes les chaînes. Afin de dédupliquer de manière fiable toutes les chaînes, la VM a besoin d'être capable de trouver chaque chaîne qui est créée. Nous faisons cela en lui donnant une table de hachage pour les stocker toutes.

^code vm-strings (1 before, 1 after)

Comme d'habitude, nous avons besoin d'un include.

^code vm-include-table (1 before, 1 after)

Quand nous démarrons une nouvelle VM, la table des chaînes est vide.

^code init-strings (1 before, 1 after)

Et quand nous éteignons la VM, nous nettoyons toutes les ressources utilisées par la table.

^code free-strings (1 before, 1 after)

Certains langages ont un type séparé ou une étape explicite pour internaliser une chaîne. Pour clox, nous internaliserons automatiquement chacune d'elles. Cela signifie que chaque fois que nous créons une nouvelle chaîne unique, nous l'ajoutons à la table.

^code allocate-store-string (1 before, 1 after)

Nous utilisons la table plus comme un _ensemble_ de hachage que comme une _table_ de hachage. Les clés sont les chaînes et ce sont toutes celles dont nous nous soucions, donc nous utilisons juste `nil` pour les valeurs.

Ceci met une chaîne dans la table en supposant qu'elle est unique, mais nous avons besoin de vérifier réellement la duplication avant d'arriver ici. Nous faisons cela dans les deux fonctions de plus haut niveau qui appellent `allocateString()`. En voici une :

^code copy-string-intern (1 before, 1 after)

Quand nous copions une chaîne dans une nouvelle LoxString, nous la cherchons dans la table des chaînes d'abord. Si nous la trouvons, au lieu de "copier", nous renvoyons juste une référence vers cette chaîne. Sinon, nous tombons à travers, allouons une nouvelle chaîne, et la stockons dans la table des chaînes.

Prendre la propriété d'une chaîne est un peu différent.

^code take-string-intern (1 before, 1 after)

Encore une fois, nous cherchons la chaîne dans la table des chaînes d'abord. Si nous la trouvons, avant de la renvoyer, nous libérons la mémoire pour la chaîne qui a été passée dedans. Puisque la propriété est passée à cette fonction et que nous n'avons plus besoin de la chaîne dupliquée, c'est à nous de la libérer.

Avant que nous arrivions à la nouvelle fonction que nous avons besoin d'écrire, il y a un include de plus.

^code object-include-table (1 before, 1 after)

Pour chercher une chaîne dans la table, nous ne pouvons pas utiliser la fonction `tableGet()` normale parce qu'elle appelle `findEntry()`, qui a le problème exact avec les chaînes dupliquées que nous essayons de fixer en ce moment. Au lieu de cela, nous utilisons cette nouvelle fonction :

^code table-find-string-h (1 before, 2 after)

L'implémentation ressemble à ceci :

^code table-find-string

Il apparaît que nous avons copié-collé `findEntry()`. Il y a beaucoup de redondance, mais aussi une couple de différences clés. D'abord, nous passons le tableau de caractères brut de la clé que nous cherchons au lieu d'un ObjString. Au point où nous appelons ceci, nous n'avons pas créé d'ObjString encore.

Deuxièmement, quand nous vérifions pour voir si nous avons trouvé la clé, nous regardons les chaînes réelles. Nous voyons d'abord si elles ont des longueurs et des hachages correspondants. Ceux-ci sont rapides à vérifier et s'ils ne sont pas égaux, les chaînes ne sont définitivement pas les mêmes.

S'il y a une collision de hachage, nous faisons une comparaison de chaîne caractère-par-caractère réelle. C'est le seul endroit dans la VM où nous testons réellement les chaînes pour l'égalité textuelle. Nous le faisons ici pour dédupliquer les chaînes et ensuite le reste de la VM peut prendre pour acquis que deux chaînes quelconques à des adresses différentes en mémoire doivent avoir des contenus différents.

En fait, maintenant que nous avons internalisé toutes les chaînes, nous pouvons tirer avantage de cela dans l'interpréteur bytecode. Quand un utilisateur fait `==` sur deux objets qui se trouvent être des chaînes, nous n'avons pas besoin de tester les caractères plus longtemps.

^code equal (1 before, 1 after)

Nous avons ajouté un peu de surcharge lors de la création de chaînes pour les internaliser. Mais en retour, à l'exécution, l'opérateur d'égalité sur les chaînes est bien plus rapide. Avec cela, nous avons une table de hachage complète prête à être utilisée pour suivre les variables, instances, ou toutes autres paires clé-valeur qui pourraient se montrer.

Nous avons aussi accéléré le test d'égalité des chaînes. C'est sympa pour quand l'utilisateur fait `==` sur des chaînes. Mais c'est encore plus critique dans un langage dynamiquement typé comme Lox où les appels de méthode et les champs d'instance sont cherchés par nom à l'exécution. Si tester une chaîne pour l'égalité est lent, alors cela signifie que chercher une méthode par nom est lent. Et si _ça_ c'est lent dans votre langage orienté objet, alors _tout_ est lent.

<div class="challenges">

## Défis

1.  Dans clox, il se trouve que nous avons seulement besoin de clés qui sont des chaînes, donc la table de hachage que nous avons construite est codée en dur pour ce type de clé. Si nous exposions les tables de hachage aux utilisateurs Lox comme une collection de première classe, il serait utile de supporter différentes sortes de clés.

    Ajoutez le support pour des clés des autres types primitifs : nombres, Booléens, et `nil`. Plus tard, clox supportera les classes définies par l'utilisateur. Si nous voulons supporter des clés qui sont des instances de ces classes, quelle sorte de complexité cela ajoute-t-il ?

1.  Les tables de hachage ont beaucoup de boutons que vous pouvez régler qui affectent leur performance. Vous décidez d'utiliser le chaînage séparé ou l'adressage ouvert. Selon quelle fourche dans cette route vous prenez, vous pouvez régler combien d'entrées sont stockées dans chaque nœud, ou la stratégie de sondage que vous utilisez. Vous contrôlez la fonction de hachage, le facteur de charge, et le taux de croissance.

    Toute cette variété n'a pas été créée juste pour donner aux candidats doctorants en CS quelque chose sur quoi <span name="publish">publier</span> des thèses : chacune a ses utilisations dans les nombreux domaines variés et scénarios matériels où le hachage entre en jeu. Cherchez quelques implémentations de table de hachage dans différents systèmes open source, recherchez les choix qu'ils ont faits, et essayez de comprendre pourquoi ils ont fait les choses de cette façon.

    <aside name="publish">

    Eh bien, au moins ce n'était pas la _seule_ raison pour laquelle elles ont été créées. Que ce soit la _principale_ raison est sujet à débat.

    </aside>

1.  Benchmarker une table de hachage est notoirement difficile. Une implémentation de table de hachage peut bien performer avec certains ensembles de clés et pauvrement avec d'autres. Elle peut marcher bien à de petites tailles mais se dégrader alors qu'elle grandit, ou vice versa. Elle peut s'étouffer quand les suppressions sont communes, mais voler quand elles ne le sont pas. Créer des benchmarks qui représentent précisément comment vos utilisateurs utiliseront la table de hachage est un défi.

    Écrivez une poignée de programmes de benchmark différents pour valider notre implémentation de table de hachage. Comment la performance varie-t-elle entre eux ? Pourquoi avez-vous choisi les cas de test spécifiques que vous avez choisis ?

</div>
