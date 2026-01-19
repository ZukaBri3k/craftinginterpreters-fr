> Les magiciens protègent leurs secrets non pas parce que les secrets sont grands et
> importants, mais parce qu'ils sont si petits et triviaux. Les merveilleux effets
> créés sur scène sont souvent le résultat d'un secret si absurde que le magicien
> serait embarrassé d'admettre que c'était comme ça que c'était fait.
>
> <cite>Christopher Priest, <em>Le Prestige</em></cite>

Nous avons passé beaucoup de temps à parler de comment représenter un programme comme une séquence d'instructions bytecode, mais cela ressemble à apprendre la biologie en n'utilisant que des animaux empaillés et morts. Nous savons ce que sont les instructions en théorie, mais nous ne les avons jamais vues en action, donc il est difficile de vraiment comprendre ce qu'elles _font_. Il serait difficile d'écrire un compilateur qui sort du bytecode quand nous n'avons pas une bonne compréhension de comment ce bytecode se comporte.

Donc, avant d'aller construire le front end de notre nouvel interpréteur, nous commencerons avec le back end -- la machine virtuelle qui exécute les instructions. Elle insuffle la vie dans le bytecode. Regarder les instructions se pavaner nous donne une image plus claire de comment un compilateur pourrait traduire le code source de l'utilisateur en une série d'entre elles.

## Une Machine d'Exécution d'Instructions

La machine virtuelle est une partie de l'architecture interne de notre interpréteur. Vous lui donnez un morceau de code -- littéralement un Chunk -- et elle l'exécute. Le code et les structures de données pour la VM résident dans un nouveau module.

^code vm-h

Comme d'habitude, nous commençons simple. La VM acquerra graduellement tout un tas d'état dont elle a besoin de garder la trace, donc nous définissons une struct maintenant pour bourrer tout ça dedans. Actuellement, tout ce que nous stockons est le morceau qu'elle exécute.

Comme nous le faisons avec la plupart des structures de données que nous créons, nous définissons aussi des fonctions pour créer et détruire une VM. Voici l'implémentation :

^code vm-c

OK, appeler ces fonctions des "implémentations" est un peu fort. Nous n'avons aucun état intéressant à initialiser ou libérer encore, donc les fonctions sont vides. Croyez-moi, nous y arriverons.

La ligne légèrement plus intéressante ici est cette déclaration de `vm`. Ce module va éventuellement avoir une flopée de fonctions et ce serait une corvée de passer un pointeur vers la VM à toutes celles-ci. Au lieu de ça, nous déclarons un unique objet VM global. Nous en avons besoin d'un seul de toute façon, et cela garde le code dans le livre un peu plus léger sur la page.

<aside name="one">

Le choix d'avoir une instance statique de VM est une concession pour le livre, mais pas nécessairement un choix d'ingénierie sain pour une implémentation de langage réelle. Si vous construisez une VM qui est conçue pour être embarquée dans d'autres applications hôtes, cela donne à l'hôte plus de flexibilité si vous prenez explicitement un pointeur de VM et le passez autour.

De cette façon, l'app hôte peut contrôler quand et où la mémoire pour la VM est allouée, lancer de multiples VMs en parallèle, etc.

Ce que je fais ici est une variable globale, et [tout ce que vous avez entendu de mauvais à propos des variables globales][global] est encore vrai quand on programme en grand. Mais quand on garde les choses petites pour un livre...

[global]: http://gameprogrammingpatterns.com/singleton.html

</aside>

Avant que nous commencions à pomper du code amusant dans notre VM, allons-y et câblons-la au point d'entrée principal de l'interpréteur.

^code main-init-vm (1 before, 1 after)

Nous démarrons la VM quand l'interpréteur commence. Puis quand nous sommes sur le point de sortir, nous l'arrêtons.

^code main-free-vm (1 before, 1 after)

Une dernière obligation cérémonielle :

^code main-include-vm (1 before, 2 after)

Maintenant quand vous lancez clox, il démarre la VM avant qu'il ne crée ce morceau écrit à la main du [dernier chapitre][]. La VM est prête et attend, donc apprenons-lui à faire quelque chose.

[dernier chapitre]: morceaux-de-bytecode.html#désassembler-des-morceaux

### Exécuter des instructions

La VM saute en action quand nous lui commandons d'interpréter un morceau de bytecode.

^code main-interpret (1 before, 1 after)

Cette fonction est le point d'entrée principal dans la VM. Elle est déclarée comme ceci :

^code interpret-h (1 before, 2 after)

La VM exécute le morceau et ensuite répond avec une valeur de cet enum :

^code interpret-result (2 before, 2 after)

Nous n'utilisons pas le résultat encore, mais quand nous aurons un compilateur qui rapporte des erreurs statiques et une VM qui détecte des erreurs d'exécution, l'interpréteur utilisera cela pour savoir comment définir le code de sortie du processus.

Nous avançons pouce par pouce vers une implémentation réelle.

^code interpret

D'abord, nous stockons le morceau étant exécuté dans la VM. Ensuite nous appelons `run()`, une fonction utilitaire interne qui exécute réellement les instructions bytecode. Entre ces deux parties est une ligne intrigante. C'est quoi cette affaire de `ip` ?

Alors que la VM travaille son chemin à travers le bytecode, elle garde la trace de où elle est -- l'emplacement de l'instruction actuellement exécutée. Nous n'utilisons pas une variable <span name="local">locale</span> à l'intérieur de `run()` pour cela parce qu'éventuellement d'autres fonctions auront besoin d'y accéder. Au lieu de cela, nous la stockons comme un champ dans VM.

<aside name="local">

Si nous essayions de presser chaque once de vitesse hors de notre interpréteur bytecode, nous stockerions `ip` dans une variable locale. Il est modifié si souvent durant l'exécution que nous voulons que le compilateur C le garde dans un registre.

</aside>

^code ip (2 before, 1 after)

Son type est un pointeur d'octet. Nous utilisons un pointeur C réel pointant droit au milieu du tableau de bytecode au lieu de quelque chose comme un index entier parce qu'il est plus rapide de déréférencer un pointeur que de chercher un élément dans un tableau par index.

Le nom "IP" est traditionnel, et -- contrairement à beaucoup de noms traditionnels en informatique -- a réellement du sens : c'est un **[pointeur d'instruction][ip]**. Presque chaque jeu d'instructions dans le <span name="ip">monde</span>, réel ou virtuel, a un registre ou une variable comme celle-ci.

[ip]: https://en.wikipedia.org/wiki/Program_counter

<aside name="ip">

x86, x64, et le CLR l'appellent "IP". 68k, PowerPC, ARM, p-code, et la JVM l'appellent "PC", pour **compteur de programme** (Program Counter).

</aside>

Nous initialisons `ip` en le pointant au premier octet de code dans le morceau. Nous n'avons pas exécuté cette instruction encore, donc `ip` pointe vers l'instruction _sur le point d'être exécutée_. Ce sera vrai durant tout le temps où la VM tourne : l'IP pointe toujours vers la prochaine instruction, pas celle actuellement gérée.

Le vrai fun se passe dans `run()`.

^code run

C'est l'unique fonction la plus <span name="important">importante</span> dans tout clox, de loin. Quand l'interpréteur exécute un programme utilisateur, il passera quelque chose comme 90% de son temps à l'intérieur de `run()`. C'est le cœur battant de la VM.

<aside name="important">

Ou, au moins, il le _sera_ dans quelques chapitres quand il aura assez de contenu pour être utile. Pour l'instant, ce n'est pas exactement une merveille de sorcellerie logicielle.

</aside>

Malgré cette intro dramatique, c'est conceptuellement assez simple. Nous avons une boucle extérieure qui va et va. Chaque tour à travers cette boucle, nous lisons et exécutons une seule instruction bytecode.

Pour traiter une instruction, nous trouvons d'abord à quel genre d'instruction nous avons affaire. La macro `READ_BYTE` lit l'octet actuellement pointé par `ip` et ensuite <span name="next">avance</span> le pointeur d'instruction. Le premier octet de n'importe quelle instruction est l'opcode. Étant donné un opcode numérique, nous devons aller au bon code C qui implémente la sémantique de cette instruction. Ce processus est appelé **décoder** ou **dispatcher** l'instruction.

<aside name="next">

Notez que `ip` avance dès que nous lisons l'opcode, avant que nous ayons réellement commencé à exécuter l'instruction. Donc, encore une fois, `ip` pointe vers le _prochain_ octet de code à être utilisé.

</aside>

Nous faisons ce processus pour chaque instruction unique, chaque fois qu'une est exécutée, donc c'est la partie la plus critique en performance de la machine virtuelle entière. Le folklore des langages de programmation est rempli de techniques <span name="dispatch">intelligentes</span> pour faire le dispatch de bytecode efficacement, remontant tout le chemin jusqu'aux premiers jours des ordinateurs.

<aside name="dispatch">

Si vous voulez apprendre certaines de ces techniques, cherchez "direct threaded code", "jump table", et "computed goto".

</aside>

Hélas, les solutions les plus rapides exigent soit des extensions non-standard à C, ou du code assembleur écrit à la main. Pour clox, nous garderons ça simple. Juste comme notre désassembleur, nous avons une unique instruction `switch` géante avec un case pour chaque opcode. Le corps de chaque case implémente le comportement de cet opcode.

Jusqu'à présent, nous gérons seulement une unique instruction, `OP_RETURN`, et la seule chose qu'elle fait est de sortir de la boucle entièrement. Éventuellement, cette instruction sera utilisée pour revenir de la fonction Lox courante, mais nous n'avons pas de fonctions encore, donc nous la réutiliserons temporairement pour finir l'exécution.

Allons-y et supportons notre seule autre instruction.

^code op-constant (1 before, 1 after)

Nous n'avons pas assez de machinerie en place pour faire quoi que ce soit d'utile avec une constante. Pour l'instant, nous l'imprimerons juste pour que nous les hackers d'interpréteur puissions voir ce qui se passe à l'intérieur de notre VM. Cet appel à `printf()` nécessite un include.

^code vm-include-stdio (1 after)

Nous avons aussi une nouvelle macro à définir.

^code read-constant (1 before, 2 after)

`READ_CONSTANT()` lit le prochain octet depuis le bytecode, traite le nombre résultant comme un index, et cherche la Value correspondante dans la table de constantes du morceau. Dans les chapitres ultérieurs, nous ajouterons quelques instructions de plus avec des opérandes qui font référence à des constantes, donc nous mettons en place cette macro utilitaire maintenant.

Comme la macro `READ_BYTE` précédente, `READ_CONSTANT` est seulement utilisée à l'intérieur de `run()`. Pour rendre cette portée plus explicite, les définitions de macro elles-mêmes sont confinées à cette fonction. Nous les <span name="macro">définissons</span> au début et -- parce que nous nous soucions -- les indéfinissons à la fin.

^code undef-read-constant (1 before, 1 after)

<aside name="macro">

Indéfinir ces macros explicitement peut sembler inutilement méticuleux, mais C tend à punir les utilisateurs négligents, et le préprocesseur C doublement.

</aside>

### Traçage d'exécution

Si vous lancez clox maintenant, il exécute le morceau que nous avons écrit à la main dans le dernier chapitre et crache `1.2` sur votre terminal. Nous pouvons voir que ça marche, mais c'est seulement parce que notre implémentation de `OP_CONSTANT` a du code temporaire pour loguer la valeur. Une fois que cette instruction fera ce qu'elle est supposée faire et tuyautera cette constante vers d'autres opérations qui veulent la consommer, la VM deviendra une boîte noire. Cela rend nos vies en tant qu'implémenteurs de VM plus dures.

Pour nous aider, maintenant est un bon moment pour ajouter un peu de journalisation de diagnostic à la VM comme nous l'avons fait avec les morceaux eux-mêmes. En fait, nous réutiliserons même le même code. Nous ne voulons pas cette journalisation activée tout le temps -- c'est juste pour nous les hackers de VM, pas les utilisateurs Lox -- donc d'abord nous créons un drapeau derrière lequel la cacher.

^code define-debug-trace (1 before, 2 after)

Quand ce drapeau est défini, la VM désassemble et imprime chaque instruction juste avant de l'exécuter. Là où notre précédent désassembleur parcourait un morceau entier une fois, statiquement, ceci désassemble les instructions dynamiquement, à la volée.

^code trace-execution (1 before, 1 after)

Puisque `disassembleInstruction()` prend un _offset_ d'octet entier et que nous stockons la référence d'instruction courante comme un pointeur direct, nous faisons d'abord un peu de maths de pointeur pour convertir `ip` en retour vers un offset relatif depuis le début du bytecode. Ensuite nous désassemblons l'instruction qui commence à cet octet.

Comme toujours, nous avons besoin d'amener la déclaration de la fonction avant que nous puissions l'appeler.

^code vm-include-debug (1 before, 1 after)

Je sais que ce code n'est pas super impressionnant pour l'instant -- c'est littéralement une instruction switch enveloppée dans une boucle `for` mais, croyez-le ou non, c'est l'un des deux composants majeurs de notre VM. Avec cela, nous pouvons exécuter impérativement des instructions. Sa simplicité est une vertu -- moins elle fait de travail, plus vite elle peut le faire. Contrastez cela avec toute la complexité et la surcharge que nous avions dans jlox avec le pattern Visiteur pour parcourir l'AST.

## Un Manipulateur de Pile de Valeurs

En plus des effets de bord impératifs, Lox a des expressions qui produisent, modifient, et consomment des valeurs. Ainsi, notre bytecode compilé a besoin d'un moyen de navetter des valeurs entre les différentes instructions qui en ont besoin. Par exemple :

```lox
print 3 - 2;
```

Nous avons évidemment besoin d'instructions pour les constantes 3 et 2, l'instruction `print`, et la soustraction. Mais comment l'instruction de soustraction sait-elle que 3 est le <span name="word">diminuende</span> et 2 est le diminuteur ? Comment l'instruction print sait-elle d'imprimer le résultat de cela ?

<aside name="word">

Oui, j'ai dû chercher "diminuteur" et "diminuende" dans un dictionnaire. Mais ne sont-ils pas des mots délicieux ? "Diminuende" sonne comme une sorte de danse élisabéthaine et "diminuteur" pourrait être une sorte de monument Paléolithique souterrain.

</aside>

Pour mettre un point plus fin là-dessus, regardez cette chose juste ici :

```lox
fun echo(n) {
  print n;
  return n;
}

print echo(echo(1) + echo(2)) + echo(echo(4) + echo(5));
```

J'ai enveloppé chaque sous-expression dans un appel à `echo()` qui imprime et renvoie son argument. Cet effet de bord signifie que nous pouvons voir l'ordre exact des opérations.

Ne vous inquiétez pas de la VM pour une minute. Pensez juste à la sémantique de Lox lui-même. Les opérandes pour un opérateur arithmétique ont évidemment besoin d'être évalués avant que nous puissions effectuer l'opération elle-même. (C'est assez dur d'ajouter `a + b` si vous ne savez pas ce que sont `a` et `b`.) Aussi, quand nous avons implémenté les expressions dans jlox, nous avons <span name="undefined">décidé</span> que l'opérande gauche doit être évalué avant le droit.

<aside name="undefined">

Nous aurions pu laisser l'ordre d'évaluation non spécifié et laisser chaque implémentation décider. Cela laisse la porte ouverte pour des compilateurs optimisants pour réordonner les expressions arithmétiques pour l'efficacité, même dans des cas où les opérandes ont des effets de bord visibles. C et Scheme laissent l'ordre d'évaluation non spécifié. Java spécifie l'évaluation de gauche à droite comme nous le faisons pour Lox.

Je pense que clouer des trucs comme ça est généralement mieux pour les utilisateurs. Quand les expressions ne sont pas évaluées dans l'ordre que les utilisateurs intuitent -- possiblement dans des ordres différents à travers différentes implémentations ! -- cela peut être un paysage infernal de douleur brûlante de comprendre ce qui se passe.

</aside>

Voici l'arbre syntaxique pour le statement `print` :

<img src="image/a-virtual-machine/ast.png" alt="L'AST pour le statement exemple, avec des nombres marquant l'ordre dans lequel les nœuds sont évalués." />

Étant donné l'évaluation de gauche à droite, et la façon dont les expressions sont imbriquées, toute implémentation Lox correcte _doit_ imprimer ces nombres dans cet ordre :

```text
1  // de echo(1)
2  // de echo(2)
3  // de echo(1 + 2)
4  // de echo(4)
5  // de echo(5)
9  // de echo(4 + 5)
12 // de print 3 + 9
```

Notre vieil interpréteur jlox accomplit cela en traversant récursivement l'AST. Il fait un parcours post-ordre. D'abord il récurse en bas de la branche de l'opérande gauche, puis l'opérande droit, puis finalement il évalue le nœud lui-même.

Après avoir évalué l'opérande gauche, jlox a besoin de stocker ce résultat quelque part temporairement pendant qu'il est occupé à traverser vers le bas à travers l'arbre d'opérande droit. Nous utilisons une variable locale en Java pour cela. Notre interpréteur à parcours d'arbre récursif crée un cadre d'appel Java unique pour chaque nœud étant évalué, donc nous pouvions avoir autant de ces variables locales que nous avions besoin.

Dans clox, notre fonction `run()` n'est pas récursive -- l'arbre d'expression imbriqué est aplati en une série linéaire d'instructions. Nous n'avons pas le luxe d'utiliser des variables locales C, donc comment et où devrions-nous stocker ces valeurs temporaires ? Vous pouvez probablement déjà <span name="guess">deviner</span>, mais je veux vraiment creuser là-dedans parce que c'est un aspect de la programmation que nous prenons pour acquis, mais nous apprenons rarement _pourquoi_ les ordinateurs sont architecturés de cette façon.

<aside name="guess">

Indice : c'est dans le nom de cette section, et c'est comment Java et C gèrent les appels récursifs aux fonctions.

</aside>

Faisons un exercice bizarre. Nous allons marcher à travers l'exécution du programme ci-dessus une étape à la fois :

<img src="image/a-virtual-machine/bars.png" alt="La série d'instructions avec des barres montrant quels nombres ont besoin d'être préservés à travers quelles instructions." />

À gauche sont les étapes de code. À droite sont les valeurs que nous suivons. Chaque barre représente un nombre. Elle commence quand la valeur est d'abord produite -- soit une constante ou le résultat d'une addition. La longueur de la barre suit quand une valeur précédemment produite a besoin d'être gardée dans le coin, et elle finit quand cette valeur est finalement consommée par une opération.

Alors que vous avancez, vous voyez des valeurs apparaître et ensuite plus tard être mangées. Celles qui vivent le plus longtemps sont les valeurs produites depuis le côté gauche d'une addition. Celles-ci restent dans le coin pendant que nous travaillons à travers l'expression opérande de droite.

Dans le diagramme ci-dessus, j'ai donné à chaque nombre unique sa propre colonne visuelle. Soyons un peu plus parcimonieux. Une fois qu'un nombre est consommé, nous permettons à sa colonne d'être réutilisée pour une autre valeur plus tard. En d'autres termes, nous prenons tous ces trous là-haut et les remplissons, poussant les nombres depuis la droite :

<img src="image/a-virtual-machine/bars-stacked.png" alt="Comme le diagramme précédent, mais avec les barres de nombres poussées vers la gauche, formant une pile." />

Il y a des trucs intéressants qui se passent ici. Quand nous décalons tout, chaque nombre réussit encore à rester dans une colonne unique pour sa vie entière. Aussi, il n'y a pas de trous laissés. En d'autres termes, chaque fois qu'un nombre apparaît plus tôt qu'un autre, alors il vivra au moins aussi longtemps que ce second. Le premier nombre à apparaître est le dernier à être consommé. Hmm... dernier-entré, premier-sorti (LIFO)... Tiens, c'est une <span name="pancakes">pile</span> !

<aside name="pancakes">

Ceci est aussi une pile :

<img src="image/a-virtual-machine/pancakes.png" alt="Une pile... de pancakes." />

</aside>

Dans le second diagramme, chaque fois que nous introduisons un nombre, nous le poussons sur la pile depuis la droite. Quand des nombres sont consommés, ils sont toujours dépilés depuis le plus à droite vers la gauche.

Puisque les valeurs temporaires que nous avons besoin de suivre ont naturellement un comportement de type pile, notre VM utilisera une pile pour les gérer. Quand une instruction "produit" une valeur, elle la pousse sur la pile. Quand elle a besoin de consommer une ou plusieurs valeurs, elle les obtient en les dépilant de la pile.

### La Pile de la VM

Peut-être que cela ne semble pas comme une révélation, mais j'_adore_ les VMs à base de pile. Quand vous voyez pour la première fois un tour de magie, cela ressemble à quelque chose de réellement magique. Mais ensuite vous apprenez comment ça marche -- habituellement quelque truc mécanique ou de la mauvaise direction -- et le sens du merveilleux s'évapore. Il y a une <span name="wonder">paire</span> d'idées en informatique où même après que je les ai démontées et appris tous les tenants et aboutissants, un peu de l'étincelle initiale est restée. Les VMs à base de pile sont l'une de celles-là.

<aside name="wonder">

Les tas (heaps) -- [la structure de données][heap], pas [le truc de gestion de la mémoire][heap mem] -- en sont une autre. Et le schéma d'analyse à précédence d'opérateur descendante de Vaughan Pratt, duquel nous apprendrons [en temps voulu][pratt].

[heap]: https://en.wikipedia.org/wiki/Heap_(data_structure)
[heap mem]: https://en.wikipedia.org/wiki/Memory_management#HEAP
[pratt]: compilation-des-expressions.html

</aside>

Comme vous le verrez dans ce chapitre, exécuter des instructions dans une VM à base de pile est mortellement <span name="cheat">simple</span>. Dans les chapitres ultérieurs, vous découvrirez aussi que compiler un langage source vers un jeu d'instructions à base de pile est du gâteau. Et pourtant, cette architecture est assez rapide pour être utilisée par des implémentations de langage en production. Cela ressemble presque à tricher au jeu du langage de programmation.

<aside name="cheat">

Pour enlever un peu du lustre : les interpréteurs à base de pile ne sont pas une solution miracle. Ils sont souvent _adéquats_, mais les implémentations modernes de la JVM, du CLR, et de JavaScript utilisent toutes des pipelines sophistiqués de [compilation à la volée][jit] (JIT) pour générer du code natif _beaucoup_ plus rapide à la volée.

[jit]: https://en.wikipedia.org/wiki/Just-in-time_compilation

</aside>

D'accord, c'est l'heure de coder ! Voici la pile :

^code vm-stack (3 before, 1 after)

Nous implémentons la sémantique de pile nous-mêmes au-dessus d'un tableau C brut. Le bas de la pile -- la première valeur poussée et la dernière à être dépilée -- est à l'élément zéro dans le tableau, et les valeurs poussées plus tard la suivent. Si nous poussons les lettres de "crepe" -- mon élément de petit-déjeuner empilable favori -- sur la pile, dans l'ordre, le tableau C résultant ressemble à ceci :

<img src="image/a-virtual-machine/array.png" alt="Un tableau contenant les lettres dans 'crepe' dans l'ordre commençant à l'élément 0." />

Puisque la pile grandit et rétrécit alors que les valeurs sont poussées et dépilées, nous avons besoin de suivre où est le sommet de la pile dans le tableau. Comme avec `ip`, nous utilisons un pointeur direct au lieu d'un index entier puisque c'est plus rapide de déréférencer le pointeur que de calculer l'offset depuis l'index chaque fois que nous en avons besoin.

Le pointeur pointe à l'élément du tableau juste _après_ l'élément contenant la valeur du sommet de la pile. Cela semble un peu bizarre, mais presque chaque implémentation fait cela. Cela signifie que nous pouvons indiquer que la pile est vide en pointant à l'élément zéro dans le tableau.

<img src="image/a-virtual-machine/stack-empty.png" alt="Un tableau vide avec stackTop pointant au premier élément." />

Si nous pointions vers l'élément du sommet, alors pour une pile vide nous aurions besoin de pointer à l'élément -1. C'est <span name="defined">indéfini</span> en C. Alors que nous poussons des valeurs sur la pile...

<aside name="defined">

Quoi à propos de quand la pile est _pleine_, vous demandez, Lecteur Malin ? Le standard C est une étape en avance sur vous. Il _est_ permis et bien spécifié d'avoir un pointeur de tableau qui pointe juste après la fin d'un tableau.

</aside>

<img src="image/a-virtual-machine/stack-c.png" alt="Un tableau avec 'c' à l'élément zéro." />

...`stackTop` pointe toujours juste après le dernier élément.

<img src="image/a-virtual-machine/stack-crepe.png" alt="Un tableau avec 'c', 'r', 'e', 'p', et 'e' dans les cinq premiers éléments." />

Je me souviens de ça comme ceci : `stackTop` pointe vers où la prochaine valeur à être poussée ira. Le nombre maximum de valeurs que nous pouvons stocker sur la pile (pour l'instant, au moins) est :

^code stack-max (1 before, 2 after)

Donner à notre VM une taille de pile fixe signifie qu'il est possible pour une certaine séquence d'instructions de pousser trop de valeurs et de tomber à court d'espace de pile -- le classique "débordement de pile" (stack overflow). Nous pourrions faire grandir la pile dynamiquement comme nécessaire, mais pour l'instant nous garderons ça simple. Puisque VM utilise Value, nous avons besoin d'inclure sa déclaration.

^code vm-include-value (1 before, 2 after)

Maintenant que VM a un état intéressant, nous pouvons l'initialiser.

^code call-reset-stack (1 before, 1 after)

Cela utilise cette fonction utilitaire :

^code reset-stack

Puisque le tableau de pile est déclaré directement inline dans la struct VM, nous n'avons pas besoin de l'allouer. Nous n'avons même pas besoin de nettoyer les cellules inutilisées dans le tableau -- nous ne les accèderons simplement pas jusqu'à ce que des valeurs aient été stockées dedans. La seule initialisation dont nous avons besoin est de définir `stackTop` pour pointer au début du tableau pour indiquer que la pile est vide.

Le protocole de pile supporte deux opérations :

^code push-pop (1 before, 2 after)

Vous pouvez pousser une nouvelle valeur sur le sommet de la pile, et vous pouvez dépiler la valeur poussée le plus récemment en retour. Voici la première fonction :

^code push

Si vous êtes rouillé sur votre syntaxe de pointeur C et opérations, c'est un bon échauffement. La première ligne stocke `value` dans l'élément du tableau au sommet de la pile. Rappelez-vous, `stackTop` pointe juste _après_ le dernier élément utilisé, au prochain disponible. Cela stocke la valeur dans cet emplacement. Ensuite nous incrémentons le pointeur lui-même pour pointer vers le prochain emplacement inutilisé dans le tableau maintenant que l'emplacement précédent est occupé.

Dépiler est l'image miroir.

^code pop

D'abord, nous déplaçons le pointeur de pile en _arrière_ pour arriver à l'emplacement utilisé le plus récent dans le tableau. Ensuite nous cherchons la valeur à cet index et la renvoyons. Nous n'avons pas besoin de l'"enlever" explicitement du tableau -- déplacer `stackTop` vers le bas est assez pour marquer cet emplacement comme n'étant plus utilisé.

### Traçage de pile

Nous avons une pile qui fonctionne, mais c'est dur de _voir_ qu'elle fonctionne. Quand nous commencerons à implémenter des instructions plus complexes et compiler et exécuter de plus gros morceaux de code, nous finirons avec beaucoup de valeurs entassées dans ce tableau. Cela rendrait nos vies en tant que hackers de VM plus faciles si nous avions une certaine visibilité dans la pile.

À cette fin, chaque fois que nous traçons l'exécution, nous montrerons aussi le contenu courant de la pile avant que nous interprétions chaque instruction.

^code trace-stack (1 before, 1 after)

Nous bouclons, imprimant chaque valeur dans le tableau, commençant à la première (bas de la pile) et finissant quand nous atteignons le sommet. Cela nous laisse observer l'effet de chaque instruction sur la pile. La sortie est assez verbeuse, mais c'est utile quand nous extrayons chirurgicalement un vilain bug des entrailles de l'interpréteur.

Pile en main, revisitons nos deux instructions. D'abord :

^code push-constant (2 before, 1 after)

Dans le dernier chapitre, j'agitais les mains à propos de comment l'instruction `OP_CONSTANT` "charge" une constante. Maintenant que nous avons une pile vous savez ce que cela signifie de réellement produire une valeur : elle est poussée sur la pile.

^code print-return (1 before, 1 after)

Ensuite nous faisons en sorte que `OP_RETURN` dépile la pile et imprime la valeur du sommet avant de sortir. Quand nous ajouterons le support pour les fonctions réelles à clox, nous changerons ce code. Mais, pour l'instant, cela nous donne un moyen d'avoir la VM exécutant des séquences d'instruction simples et affichant le résultat.

## Une Calculatrice Arithmétique

Le cœur et l'âme de notre VM sont en place maintenant. La boucle de bytecode dispatche et exécute les instructions. La pile grandit et rétrécit alors que les valeurs coulent à travers elles. Les deux moitiés fonctionnent, mais c'est dur d'avoir un sentiment pour comment intelligemment elles interagissent avec seulement les deux instructions rudimentaires que nous avons jusqu'ici. Donc apprenons à notre interpréteur à faire de l'arithmétique.

Nous commencerons avec l'opération arithmétique la plus simple, la négation unaire.

```lox
var a = 1.2;
print -a; // -1.2.
```

L'opérateur préfixe `-` prend un opérande, la valeur à nier. Il produit un seul résultat. Nous ne nous en faisons pas avec un parseur encore, mais nous pouvons ajouter l'instruction bytecode vers laquelle la syntaxe ci-dessus compilera.

^code negate-op (1 before, 1 after)

Nous l'exécutons comme ceci :

^code op-negate (1 before, 1 after)

L'instruction a besoin d'une valeur sur laquelle opérer, qu'elle obtient en dépilant de la pile. Elle nie cela, puis pousse le résultat en retour pour que les instructions ultérieures l'utilisent. Ça ne devient pas beaucoup plus facile que ça. Nous pouvons la désassembler aussi.

^code disassemble-negate (2 before, 1 after)

Et nous pouvons l'essayer dans notre morceau de test.

^code main-negate (1 before, 2 after)

Après avoir chargé la constante, mais avant de retourner, nous exécutons l'instruction de négation. Cela remplace la constante sur la pile avec sa négation. Ensuite l'instruction de retour imprime cela :

```text
-1.2
```

Magique !

### Opérateurs binaires

OK, les opérateurs unaires ne sont pas _si_ impressionnants. Nous avons encore seulement jamais une valeur unique sur la pile. Pour voir vraiment de la profondeur, nous avons besoin d'opérateurs binaires. Lox a quatre opérateurs <span name="ops">arithmétiques</span> binaires : addition, soustraction, multiplication, et division. Nous allons aller de l'avant et les implémenter tous en même temps.

<aside name="ops">

Lox a quelques autres opérateurs binaires -- comparaison et égalité -- mais ceux-là ne produisent pas de nombres comme résultat, donc nous ne sommes pas prêts pour eux encore.

</aside>

^code binary-ops (1 before, 1 after)

De retour dans la boucle bytecode, ils sont exécutés comme ceci :

^code op-binary (1 before, 1 after)

La seule différence entre ces quatre instructions est quel opérateur C sous-jacent elles utilisent ultimement pour combiner les deux opérandes. Autour de cette expression arithmétique centrale est un peu de code boilerplate pour tirer les valeurs de la pile et pousser le résultat. Quand nous ajouterons plus tard le typage dynamique, ce boilerplate grandira. Pour éviter de répéter ce code quatre fois, je l'ai enveloppé dans une macro.

^code binary-op (1 before, 2 after)

J'admets que c'est un usage assez <span name="operator">aventureux</span> du préprocesseur C. J'ai hésité à faire cela, mais vous serez content dans les chapitres ultérieurs quand nous aurons besoin d'ajouter la vérification de type pour chaque opérande et tout ça. Ce serait une corvée de vous faire marcher à travers le même code quatre fois.

<aside name="operator">

Saviez-vous même que vous pouvez passer un _opérateur_ comme argument à une macro ? Maintenant vous savez. Le préprocesseur ne se soucie pas que les opérateurs ne soient pas de première classe en C. Pour autant qu'il soit concerné, c'est tout juste des tokens de texte.

Je sais, vous pouvez juste _sentir_ la tentation d'abuser de ça, n'est-ce pas ?

</aside>

Si vous n'êtes pas familier avec le truc déjà, cette boucle `do while` extérieure semble probablement vraiment bizarre. Cette macro a besoin de s'étendre en une série d'instructions. Pour être des auteurs de macro prudents, nous voulons nous assurer que ces instructions finissent toutes dans la même portée quand la macro est étendue. Imaginez si vous définissiez :

```c
#define WAKE_UP() makeCoffee(); drinkCoffee();
```

Et ensuite l'utilisiez comme :

```c
if (morning) WAKE_UP();
```

L'intention est d'exécuter les deux instructions du corps de la macro seulement si `morning` est vrai. Mais ça s'étend à :

```c
if (morning) makeCoffee(); drinkCoffee();;
```

Oups. Le `if` s'attache seulement à la _première_ instruction. Vous pourriez penser que vous pourriez corriger cela en utilisant un bloc.

```c
#define WAKE_UP() { makeCoffee(); drinkCoffee(); }
```

C'est mieux, mais vous risquez encore :

```c
if (morning)
  WAKE_UP();
else
  sleepIn();
```

Maintenant vous obtenez une erreur de compilation sur le `else` à cause de ce `;` traînant après le bloc de la macro. Utiliser une boucle `do while` dans la macro semble drôle, mais cela vous donne un moyen de contenir de multiples instructions à l'intérieur d'un bloc qui permet _aussi_ un point-virgule à la fin.

Où étions-nous ? Juste, donc ce que le corps de cette macro fait est direct. Un opérateur binaire prend deux opérandes, donc il dépile deux fois. Il effectue l'opération sur ces deux valeurs et ensuite pousse le résultat.

Payez une attention proche à l'_ordre_ des deux dépilements. Notez que nous assignons le premier opérande dépilé à `b`, pas `a`. Ça semble à l'envers. Quand les opérandes eux-mêmes sont calculés, le gauche est évalué d'abord, puis le droit. Cela signifie que l'opérande gauche est poussé avant l'opérande droit. Donc l'opérande droit sera au sommet de la pile. Ainsi, la première valeur que nous dépilons est `b`.

Par exemple, si nous compilons `3 - 1`, le flux de données entre les instructions ressemble à ceci :

<img src="image/a-virtual-machine/reverse.png" alt="Une séquence d'instructions avec la pile pour chacune montrant comment pousser et ensuite dépiler les valeurs inverse leur ordre." />

Comme nous l'avons fait avec les autres macros à l'intérieur de `run()`, nous nettoyons après nous-mêmes à la fin de la fonction.

^code undef-binary-op (1 before, 1 after)

Le dernier est le support du désassembleur.

^code disassemble-binary (2 before, 1 after)

Les formats d'instruction arithmétique sont simples, comme `OP_RETURN`. Même si les _opérateurs_ arithmétiques prennent des opérandes -- qui sont trouvés sur la pile -- les _instructions bytecode_ arithmétiques ne le font pas.

Mettons certaines de nos nouvelles instructions à l'épreuve en évaluant une plus grosse expression :

<img src="image/a-virtual-machine/chunk.png" alt="L'expression étant évaluée : -((1.2 + 3.4) / 5.6)" />

Construisant sur notre exemple de morceau existant, voici les instructions additionnelles que nous avons besoin de compiler à la main de cet AST vers le bytecode.

^code main-chunk (3 before, 3 after)

L'addition va en premier. L'instruction pour la constante de gauche, 1.2, est déjà là, donc nous en ajoutons une autre pour 3.4. Ensuite nous ajoutons ces deux en utilisant `OP_ADD`, laissant cela sur la pile. Cela couvre le côté gauche de la division. Ensuite nous poussons le 5.6, et divisons le résultat de l'addition par lui. Finalement, nous nions le résultat de cela.

Notez comment la sortie de `OP_ADD` coule implicitement en étant un opérande de `OP_DIVIDE` sans qu'aucune instruction ne soit directement couplée l'une à l'autre. C'est la magie de la pile. Elle nous laisse composer librement des instructions sans qu'elles aient besoin d'aucune complexité ou conscience du flux de données. La pile agit comme un espace de travail partagé dans lequel elles lisent et écrivent toutes.

Dans ce minuscule morceau exemple, la pile devient seulement haute de deux valeurs, mais quand nous commencerons à compiler du code source Lox vers du bytecode, nous aurons des morceaux qui utilisent beaucoup plus de la pile. En attendant, essayez de jouer avec ce morceau écrit à la main pour calculer différentes expressions arithmétiques imbriquées et voyez comment les valeurs coulent à travers les instructions et la pile.

Vous pourriez aussi bien sortir ça de votre système maintenant. C'est le dernier morceau que nous construirons à la main. La prochaine fois que nous revisiterons le bytecode, nous écrirons un compilateur pour le générer pour nous.

<div class="challenges">

## Défis

1.  Quelles séquences d'instructions bytecode généreriez-vous pour les expressions suivantes :

    ```lox
    1 * 2 + 3
    1 + 2 * 3
    3 - 2 - 1
    1 + 2 * 3 - 4 / -5
    ```

    (Rappelez-vous que Lox n'a pas de syntaxe pour les littéraux de nombres négatifs, donc le `-5` nie le nombre 5.)

2.  Si nous voulions vraiment un jeu d'instructions minimal, nous pourrions éliminer soit `OP_NEGATE` ou `OP_SUBTRACT`. Montrez la séquence d'instructions bytecode que vous généreriez pour :

    ```lox
    4 - 3 * -2
    ```

    D'abord, sans utiliser `OP_NEGATE`. Ensuite, sans utiliser `OP_SUBTRACT`.

    Étant donné le ci-dessus, pensez-vous que cela a du sens d'avoir les deux instructions ? Pourquoi ou pourquoi pas ? Y a-t-il d'autres instructions redondantes que vous considéreriez inclure ?

3.  La pile de notre VM a une taille fixe, et nous ne vérifions pas si pousser une valeur la fait déborder. Cela signifie que la mauvaise série d'instructions pourrait causer le crash de notre interpréteur ou aller en comportement indéfini. Évitez cela en faisant grandir la pile dynamiquement comme nécessaire.

    Quels sont les coûts et bénéfices de faire ainsi ?

4.  Pour interpréter `OP_NEGATE`, nous dépilons l'opérande, nions la valeur, et ensuite poussons le résultat. C'est une implémentation simple, mais elle incrémente et décrémente `stackTop` inutilement, puisque la pile finit à la même hauteur à la fin. Il pourrait être plus rapide de simplement nier la valeur en place sur la pile et laisser `stackTop` tranquille. Essayez cela et voyez si vous pouvez mesurer une différence de performance.

    Y a-t-il d'autres instructions où vous pouvez faire une optimisation similaire ?

</div>

<div class="design-note">

## Note de Conception : Bytecode à Registres

Pour le reste de ce livre, nous implémenterons méticuleusement un interpréteur autour d'un jeu d'instructions bytecode basé sur une pile. Il y a une autre famille d'architectures bytecode là-dehors -- _basées sur des registres_. Malgré le nom, ces instructions bytecode ne sont pas tout à fait aussi difficiles à travailler qu'avec les registres dans une puce réelle comme <span name="x64">x64</span>. Avec des registres matériels réels, vous en avez habituellement seulement une poignée pour le programme entier, donc vous passez beaucoup d'effort [à essayer de les utiliser efficacement et à navetter des trucs dedans et dehors][register allocation].

[register allocation]: https://en.wikipedia.org/wiki/Register_allocation

<aside name="x64">

Le bytecode à registres est un peu plus proche des [_fenêtres de registres_][window] supportées par les puces SPARC.

[window]: https://en.wikipedia.org/wiki/Register_window

</aside>

Dans une VM à registres, vous avez encore une pile. Les valeurs temporaires sont encore poussées dessus et dépilées quand elles ne sont plus nécessaires. La différence principale est que les instructions peuvent lire leurs entrées de n'importe où dans la pile et peuvent stocker leurs sorties dans des emplacements de pile spécifiques.

Prenez ce petit script Lox :

```lox
var a = 1;
var b = 2;
var c = a + b;
```

Dans notre VM à pile, le dernier statement sera compilé vers quelque chose comme :

```lox
load <a>  // Lire la variable locale a et pousser sur la pile.
load <b>  // Lire la variable locale b et pousser sur la pile.
add       // Dépiler deux valeurs, ajouter, pousser le résultat.
store <c> // Dépiler la valeur et stocker dans la variable locale c.
```

(Ne vous inquiétez pas si vous ne comprenez pas pleinement les instructions load et store encore. Nous les passerons en revue en bien plus grand détail [quand nous implémenterons les variables][variables].) Nous avons quatre instructions séparées. Cela signifie quatre fois à travers la boucle d'interprétation de bytecode, quatre instructions à décoder et dispatcher. C'est au moins sept octets de code -- quatre pour les opcodes et trois autres pour les opérandes identifiant quels locaux charger et stocker. Trois empilements et trois dépilements. Beaucoup de travail !

[variables]: variables-globales.html

Dans un jeu d'instructions à registres, les instructions peuvent lire depuis et stocker directement dans les variables locales. Le bytecode pour le dernier statement ci-dessus ressemble à :

```lox
add <a> <b> <c> // Lire les valeurs de a et b, ajouter, stocker dans c.
```

L'instruction d'ajout est plus grosse -- elle a trois opérandes d'instruction qui définissent où dans la pile elle lit ses entrées et écrit le résultat. Mais puisque les variables locales vivent sur la pile, elle peut lire directement de `a` et `b` et ensuite stocker le résultat droit dans `c`.

Il y a seulement une unique instruction à décoder et dispatcher, et le truc entier tient dans quatre octets. Le décodage est plus complexe à cause des opérandes additionnels, mais c'est toujours un gain net. Il n'y a pas d'empilement et dépilement ou autre manipulation de pile.

L'implémentation principale de Lua avait l'habitude d'être basée sur une pile. Pour <span name="lua">Lua 5.0</span>, les implémenteurs ont changé pour un jeu d'instructions à registres et noté une amélioration de vitesse. Le montant de l'amélioration, naturellement, dépend lourdement des détails de la sémantique du langage, du jeu d'instructions spécifique, et de la sophistication du compilateur, mais cela devrait attirer votre attention.

<aside name="lua">

L'équipe de dev Lua -- Roberto Ierusalimschy, Waldemar Celes, et Luiz Henrique de Figueiredo -- a écrit un papier _fantastique_ là-dessus, un de mes papiers d'informatique favoris de tous les temps, "[The Implementation of Lua 5.0][lua]" (PDF).

[lua]: https://www.lua.org/doc/jucs05.pdf

</aside>

Cela soulève la question évidente de pourquoi je vais passer le reste du livre à faire un bytecode basé sur une pile. Les VMs à registres sont chouettes, mais elles sont un peu plus dures pour lesquelles écrire un compilateur. Pour ce qui est probablement votre tout premier compilateur, je voulais rester avec un jeu d'instructions qui est facile à générer et facile à exécuter. Le bytecode à pile est merveilleusement simple.

Il est aussi _bien_ mieux connu dans la littérature et la communauté. Même si vous pouvez éventuellement bouger vers quelque chose de plus avancé, c'est un bon terrain commun à partager avec le reste de vos pairs hackers de langages.

</div>
