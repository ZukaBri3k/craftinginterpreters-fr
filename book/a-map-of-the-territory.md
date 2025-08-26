> Vous devez avoir une carte, même sommaire. Sinon, vous vous promenez partout.  
> Dans *Le Seigneur des Anneaux*, je n’ai jamais fait aller quelqu’un plus loin qu’il ne pouvait le faire un jour donné.
>
> <cite>J. R. R. Tolkien</cite>

Nous ne voulons pas nous promener partout, donc avant de partir, parcourons le territoire tracé par les implémenteurs de langages précédents.  
Cela nous aidera à comprendre où nous allons et les routes alternatives que d’autres ont empruntées.  

Tout d’abord, permettez-moi d’établir une abréviation.  
Une grande partie de ce livre traite de l’*implémentation* d’un langage, ce qui est distinct du *langage lui-même* dans une sorte de forme idéale platonique.  
Des choses comme « pile », « bytecode » et « descente récursive » sont des rouages qu’une implémentation particulière pourrait utiliser.  
Du point de vue de l’utilisateur, tant que le mécanisme final suit fidèlement la spécification du langage, ce sont tous des détails d’implémentation.  

Nous allons passer beaucoup de temps sur ces détails, donc si je devais écrire « implémentation de langage » chaque fois que je les mentionne, je m’userais les doigts.  
À la place, j’utiliserai « langage » pour désigner soit un langage, soit une implémentation de celui-ci, ou les deux, sauf si la distinction importe.  

## Les parties d’un langage

Les ingénieurs construisent des langages de programmation depuis les âges sombres de l’informatique.  
Dès que nous avons pu parler aux ordinateurs, nous avons découvert que c’était trop difficile, et nous avons sollicité leur aide.  
Je trouve fascinant que, même si les machines d’aujourd’hui sont littéralement un million de fois plus rapides et disposent de plusieurs ordres de grandeur de stockage supplémentaires, la manière dont nous construisons les langages de programmation est pratiquement inchangée.  

Bien que la zone explorée par les concepteurs de langages soit vaste, les sentiers qu’ils ont tracés à travers elle sont <span name="dead">peu nombreux</span>.  
Tous les langages ne suivent pas exactement le même chemin — certains prennent un ou deux raccourcis — mais sinon, ils sont rassurants similaires, depuis le premier compilateur COBOL de l’amiral Rear Grace Hopper jusqu’à un langage tout chaud et nouveau transpilé vers JavaScript dont la « documentation » consiste entièrement en un seul README mal édité dans un dépôt Git quelque part.  

<aside name="dead">

Il y a certainement des impasses, de tristes petits cul-de-sacs de publications en informatique avec zéro citation et des optimisations aujourd’hui oubliées qui n’avaient de sens que lorsque la mémoire se mesurait en octets individuels.  

</aside>

Je visualise le réseau de chemins qu’une implémentation peut emprunter comme l’ascension d’une montagne.  
Vous commencez au bas avec le programme sous forme de texte brut, littéralement juste une chaîne de caractères.  
Chaque phase analyse le programme et le transforme en une représentation de plus haut niveau où la sémantique — ce que l’auteur veut que l’ordinateur fasse — devient plus apparente.  

Finalement, nous atteignons le sommet.  
Nous avons une vue d’ensemble du programme de l’utilisateur et pouvons voir ce que son code *signifie*.  
Nous commençons notre descente de l’autre côté de la montagne.  
Nous transformons cette représentation de plus haut niveau en formes de plus en plus bas niveau pour nous rapprocher de quelque chose que nous savons faire exécuter réellement par le CPU.  

<img src="image/a-map-of-the-territory/mountain.png" alt="Les chemins bifurquants qu’un langage peut emprunter sur la montagne." class="wide" />

Parcourons chacun de ces sentiers et points d’intérêt.  
Notre voyage commence à gauche avec le texte brut du code source de l’utilisateur :

<img src="image/a-map-of-the-territory/string.png" alt="var average = (min + max) / 2;" />

### Analyse lexicale

La première étape est **l’analyse lexicale**, aussi appelée **lexing**, ou (si vous essayez d’impressionner quelqu’un) **analyse lexicale**.  
Tout cela signifie à peu près la même chose.  
J’aime « lexing » parce que cela sonne comme quelque chose qu’un super-vilain maléfique ferait, mais j’utiliserai « analyse lexicale » car cela semble légèrement plus courant.  

Un **scanner** (ou **lexer**) prend le flux linéaire de caractères et les regroupe en une série de quelque chose de plus proche des <span name="word">« mots »</span>.  
Dans les langages de programmation, chacun de ces mots est appelé un **token**.  
Certains tokens sont des caractères uniques, comme `(` et `,`.  
D’autres peuvent comporter plusieurs caractères, comme les nombres (`123`), les littéraux de chaîne (`"hi!"`) et les identifiants (`min`).  

<aside name="word">

« Lexical » vient de la racine grecque « lex », qui signifie « mot ».  

</aside>

Certains caractères dans un fichier source ne signifient en réalité rien.  
Les espaces sont souvent insignifiants, et les commentaires, par définition, sont ignorés par le langage.  
Le scanner les élimine généralement, laissant une séquence propre de tokens significatifs.  

<img src="image/a-map-of-the-territory/tokens.png" alt="[var] [average] [=] [(] [min] [+] [max] [)] [/] [2] [;]" />


### Analyse syntaxique

L’étape suivante est **l’analyse syntaxique**.  
C’est là que notre syntaxe obtient une **grammaire** — la capacité de composer des expressions et instructions plus grandes à partir de parties plus petites.  
Avez-vous déjà schématisé des phrases en cours d’anglais ?  
Si oui, vous avez fait ce que fait un analyseur syntaxique, sauf que l’anglais possède des milliers et des milliers de « mots-clés » et une corne d’abondance d’ambiguïtés.  
Les langages de programmation sont beaucoup plus simples.  

Un **analyseur syntaxique** prend la séquence linéaire de tokens et construit une structure arborescente qui reflète la nature imbriquée de la grammaire.  
Ces arbres ont plusieurs noms différents — **arbre de dérivation** ou **arbre syntaxique abstrait** — selon la proximité avec la structure syntaxique brute du langage source.  
En pratique, les concepteurs de langages les appellent généralement **arbres syntaxiques**, **AST**, ou souvent simplement **arbres**.  

<img src="image/a-map-of-the-territory/ast.png" alt="Un arbre syntaxique abstrait." />

L’analyse syntaxique a une longue et riche histoire en informatique, étroitement liée à la communauté de l’intelligence artificielle.  
Beaucoup des techniques utilisées aujourd’hui pour analyser les langages de programmation ont été initialement conçues pour analyser les langages *humains* par des chercheurs en IA qui essayaient de faire parler les ordinateurs avec nous.  

Il s’avère que les langues humaines étaient trop désordonnées pour les grammaires rigides que ces analyseurs pouvaient gérer, mais elles convenaient parfaitement aux grammaires artificielles plus simples des langages de programmation.  
Hélas, nous, les humains imparfaits, parvenons encore à utiliser ces grammaires simples de manière incorrecte, donc le travail de l’analyseur inclut également de nous signaler quand nous le faisons en rapportant des **erreurs de syntaxe**.  

### Analyse statique

Les deux premières étapes sont assez similaires pour toutes les implémentations.  
Maintenant, les caractéristiques individuelles de chaque langage commencent à entrer en jeu.  
À ce stade, nous connaissons la structure syntaxique du code — par exemple quelles expressions sont imbriquées dans lesquelles — mais nous n’en savons pas beaucoup plus.  

Dans une expression comme `a + b`, nous savons que nous additionnons `a` et `b`, mais nous ne savons pas à quoi ces noms font référence.  
S’agit-il de variables locales ? Globales ? Où sont-elles définies ?  

Le premier type d’analyse que la plupart des langages effectuent s’appelle **liaison** ou **résolution**.  
Pour chaque **identifiant**, nous découvrons où ce nom est défini et relions les deux.  
C’est là que le concept de **portée** entre en jeu — la zone du code source où un certain nom peut être utilisé pour faire référence à une certaine déclaration.  

Si le langage est <span name="type">typé statiquement</span>, c’est à ce moment que nous effectuons le contrôle de type.  
Une fois que nous savons où `a` et `b` sont déclarés, nous pouvons également déterminer leurs types.  
Puis, si ces types ne supportent pas d’être additionnés entre eux, nous signalons une **erreur de type**.  

<aside name="type">

Le langage que nous construirons dans ce livre est typé dynamiquement, donc il effectuera son contrôle de type plus tard, à l’exécution.

</aside>

Respirez profondément. Nous avons atteint le sommet de la montagne et une vue panoramique du programme de l’utilisateur.  
Toutes ces informations sémantiques visibles depuis l’analyse doivent être stockées quelque part.  
Il y a plusieurs endroits où nous pouvons les placer :  

* Souvent, elles sont stockées directement comme des **attributs** sur l’arbre syntaxique lui-même — des champs supplémentaires dans les nœuds qui ne sont pas initialisés pendant l’analyse syntaxique mais qui sont remplis plus tard.  

* Parfois, nous stockons les données dans une table de consultation à côté.  
  En général, les clés de cette table sont des identifiants — noms de variables et de déclarations.  
  Dans ce cas, nous l’appelons une **table de symboles** et les valeurs associées à chaque clé indiquent à quoi se réfère cet identifiant.  

* L’outil de gestion le plus puissant consiste à transformer l’arbre en une toute nouvelle structure de données qui exprime plus directement la sémantique du code.  
  C’est la section suivante.  

Tout ce qui précède est considéré comme le **front-end** de l’implémentation.  
Vous pourriez deviner que tout ce qui suit est le **back-end**, mais non.  
À l’époque où les termes « front-end » et « back-end » ont été inventés, les compilateurs étaient beaucoup plus simples.  
Des chercheurs ultérieurs ont inventé de nouvelles phases à insérer entre les deux moitiés.  
Plutôt que de jeter les anciens termes, William Wulf et ses collègues ont regroupé ces nouvelles phases sous le nom charmant mais spatialement paradoxal de **middle-end**.  

### Représentations intermédiaires

Vous pouvez considérer le compilateur comme un pipeline où la tâche de chaque étape est d’organiser les données représentant le code de l’utilisateur de manière à simplifier la mise en œuvre de l’étape suivante.  
Le front-end du pipeline est spécifique au langage source dans lequel le programme est écrit.  
Le back-end concerne l’architecture finale sur laquelle le programme s’exécutera.  

Au milieu, le code peut être stocké dans une <span name="ir">**représentation intermédiaire**</span> (**IR**) qui n’est pas strictement liée ni à la forme source ni à la forme destination (d’où le terme « intermédiaire »).  
Au lieu de cela, l’IR agit comme une interface entre ces deux langages.  

<aside name="ir">

Il existe quelques styles d’IR bien établis.  
Faites une recherche sur Internet pour « graphe de flux de contrôle », « affectation unique statique », « style de passage de continuation » et « code à trois adresses ».  

</aside>

Cela vous permet de supporter plusieurs langages sources et plateformes cibles avec moins d’effort.  
Disons que vous voulez implémenter des compilateurs pour Pascal, C et Fortran, et que vous voulez cibler x86, ARM, et, je ne sais pas, SPARC.  
Normalement, cela signifie que vous devez écrire *neuf* compilateurs complets : Pascal&rarr;x86, C&rarr;ARM, et chaque autre combinaison.  

Une <span name="gcc">représentation intermédiaire partagée</span> réduit cela de façon spectaculaire.  
Vous écrivez *un* front-end pour chaque langage source qui produit l’IR.  
Puis *un* back-end pour chaque architecture cible.  
Maintenant, vous pouvez combiner ces éléments pour obtenir toutes les combinaisons.  

<aside name="gcc">

Si vous vous êtes déjà demandé comment [GCC][] prend en charge tant de langages et architectures différents, comme Modula-3 sur Motorola 68k, vous savez maintenant.  
Les front-ends des langages ciblent une poignée d’IR, principalement [GIMPLE][] et [RTL][].  
Les back-ends cibles, comme celui pour 68k, prennent ensuite ces IR et produisent du code natif.  

[gcc]: https://en.wikipedia.org/wiki/GNU_Compiler_Collection
[gimple]: https://gcc.gnu.org/onlinedocs/gccint/GIMPLE.html
[rtl]: https://gcc.gnu.org/onlinedocs/gccint/RTL.html

</aside>

Il y a une autre grande raison pour laquelle nous pourrions vouloir transformer le code en une forme qui rend la sémantique plus apparente...


### Optimisation

Une fois que nous comprenons ce que signifie le programme de l'utilisateur, nous pouvons le remplacer par un programme différent qui a les *mêmes sémantiques* mais qui les implémente plus efficacement — nous pouvons **l'optimiser**.

Un exemple simple est le **pliage de constantes** : si une expression évalue toujours exactement la même valeur, nous pouvons effectuer l’évaluation à la compilation et remplacer le code de l’expression par son résultat. Si l’utilisateur a tapé ceci :


```java
pennyArea = 3.14159 * (0.75 / 2) * (0.75 / 2);
```

Nous pourrions effectuer tous ces calculs dans le compilateur et remplacer le code par :

```java
pennyArea = 0.4417860938;
```

L’optimisation est une énorme partie du métier des langages de programmation. Beaucoup de hackers de langage passent leur carrière entière ici, tirant chaque goutte de performance possible de leurs compilateurs pour rendre leurs benchmarks légèrement plus rapides. Cela peut devenir une sorte d’obsession.

Nous allons surtout <span name="rathole">sauter par-dessus ce gouffre</span> dans ce livre. Beaucoup de langages à succès ont étonnamment peu d’optimisations à la compilation. Par exemple, Lua et CPython génèrent un code relativement non optimisé et concentrent la majeure partie de leurs efforts de performance sur le temps d’exécution.

<aside name="rathole">

Si vous ne pouvez pas résister à l’envie de mettre un pied dans ce gouffre, quelques mots-clés pour commencer sont « propagation de constantes », « élimination des sous-expressions communes », « mouvement de code invariant dans les boucles », « numérotation globale des valeurs », « réduction de force », « remplacement scalaire des agrégats », « élimination de code mort » et « déroulement de boucle ».

</aside>

### Génération de code

Nous avons appliqué toutes les optimisations possibles au programme de l’utilisateur. La dernière étape consiste à le convertir en une forme que la machine peut réellement exécuter. En d’autres termes, **génération de code** (ou **code gen**), où « code » fait généralement référence au type d’instructions primitives proches de l’assembleur qu’un CPU exécute, et non au type de « code source » qu’un humain voudrait lire.

Enfin, nous sommes dans le **back end**, descendant de l’autre côté de la montagne. À partir de maintenant, notre représentation du code devient de plus en plus primitive, comme une évolution à l’envers, à mesure que nous nous rapprochons de quelque chose que notre machine simple d’esprit peut comprendre.

Nous devons prendre une décision. Générons-nous des instructions pour un CPU réel ou pour un CPU virtuel ? Si nous générons du code machine réel, nous obtenons un exécutable que le système d’exploitation peut charger directement sur la puce. Le code natif est extrêmement rapide, mais le générer demande beaucoup de travail. Les architectures actuelles ont des tas d’instructions, des pipelines complexes et assez de <span name="aad">bagages historiques</span> pour remplir la soute d’un 747.

Parler le langage de la puce signifie également que votre compilateur est lié à une architecture spécifique. Si votre compilateur cible le code machine [x86][], il ne fonctionnera pas sur un appareil [ARM][]. Dès les années 60, pendant l’explosion cambrienne des architectures informatiques, ce manque de portabilité constituait un obstacle réel.

<aside name="aad">

Par exemple, l’instruction [AAD][] (« ASCII Adjust AX Before Division ») vous permet d’effectuer une division, ce qui semble utile. Sauf que cette instruction prend, comme opérandes, deux chiffres décimaux codés en binaire empaquetés dans un seul registre 16 bits. Quand avez-vous eu besoin pour la dernière fois du BCD sur une machine 16 bits ?

[aad]: http://www.felixcloutier.com/x86/AAD.html

</aside>

[x86]: https://en.wikipedia.org/wiki/X86
[arm]: https://en.wikipedia.org/wiki/ARM_architecture

Pour contourner ce problème, des hackers comme Martin Richards et Niklaus Wirth, respectivement de BCPL et Pascal, ont fait en sorte que leurs compilateurs produisent du code pour une machine *virtuelle*. Au lieu d’instructions pour une puce réelle, ils produisaient du code pour une machine hypothétique et idéalisée. Wirth appelait cela le **p-code** pour *portable*, mais aujourd’hui, nous l’appelons généralement **bytecode** car chaque instruction est souvent longue d’un seul octet.

Ces instructions synthétiques sont conçues pour correspondre un peu plus étroitement à la sémantique du langage, et ne pas être trop liées aux particularités d’une architecture informatique spécifique et à son bagage historique accumulé. Vous pouvez les considérer comme un encodage binaire dense des opérations bas niveau du langage.

### Machine virtuelle

Si votre compilateur produit du bytecode, votre travail n’est pas terminé une fois cela fait. Comme aucune puce ne comprend ce bytecode, c’est à vous de le traduire. Là encore, vous avez deux options. Vous pouvez écrire un petit mini-compilateur pour chaque architecture cible qui convertit le bytecode en code natif pour cette machine. Vous devez encore travailler pour <span name="shared">chaque</span> puce que vous supportez, mais cette dernière étape est assez simple et vous permet de réutiliser le reste du pipeline du compilateur sur toutes les machines que vous supportez. Vous utilisez essentiellement votre bytecode comme représentation intermédiaire.

<aside name="shared" class="bottom">

Le principe de base ici est que plus vous poussez le travail spécifique à l’architecture vers le bas dans le pipeline, plus vous pouvez partager les phases précédentes entre architectures.

Il existe cependant une tension. Beaucoup d’optimisations, comme l’allocation de registres et la sélection d’instructions, fonctionnent mieux lorsqu’elles connaissent les forces et les capacités d’une puce spécifique. Déterminer quelles parties de votre compilateur peuvent être partagées et lesquelles devraient être spécifiques à la cible est un art.

</aside>

Ou vous pouvez écrire une <span name="vm">**machine virtuelle**</span> (**VM**), un programme qui émule une puce hypothétique supportant votre architecture virtuelle à l’exécution. Exécuter du bytecode dans une VM est plus lent que de le traduire en code natif à l’avance, car chaque instruction doit être simulée à l’exécution à chaque fois qu’elle est exécutée. En retour, vous obtenez simplicité et portabilité. Implémentez votre VM en, par exemple, C, et vous pourrez exécuter votre langage sur n’importe quelle plateforme disposant d’un compilateur C. C’est ainsi que fonctionne le second interpréteur que nous construisons dans ce livre.

<aside name="vm">

Le terme « machine virtuelle » fait également référence à un type différent d’abstraction. Une **machine virtuelle système** émule une plateforme matérielle entière et un système d’exploitation en logiciel. C’est ainsi que vous pouvez jouer à des jeux Windows sur votre machine Linux, et comment les fournisseurs cloud offrent à leurs clients l’expérience utilisateur de contrôler leur propre « serveur » sans avoir besoin d’allouer physiquement des ordinateurs séparés pour chaque utilisateur.

Le type de VM dont nous parlerons dans ce livre sont des **machines virtuelles de langage** ou des **machines virtuelles de processus** si vous voulez être précis.

</aside>


### Exécution

Nous avons enfin transformé le programme de l'utilisateur en une forme que nous pouvons exécuter. La dernière étape consiste à le lancer. Si nous l'avons compilé en code machine, nous demandons simplement au système d'exploitation de charger l'exécutable et c'est parti. Si nous l'avons compilé en bytecode, nous devons démarrer la VM et y charger le programme.

Dans les deux cas, pour tous les langages de bas niveau sauf les plus simples, nous avons généralement besoin de certains services que notre langage fournit pendant que le programme s'exécute. Par exemple, si le langage gère automatiquement la mémoire, nous avons besoin d'un ramasse-miettes pour récupérer les morceaux inutilisés. Si notre langage supporte les tests "instance of" pour vérifier quel type d'objet nous avons, alors nous avons besoin d'une représentation pour suivre le type de chaque objet pendant l'exécution.

Tout cela se passe à l'exécution, donc on appelle cela, à juste titre, le **runtime**. Dans un langage entièrement compilé, le code implémentant le runtime est directement inséré dans l'exécutable résultant. Dans, par exemple, [Go][], chaque application compilée contient sa propre copie du runtime de Go directement intégrée. Si le langage s'exécute à l'intérieur d'un interpréteur ou d'une VM, alors le runtime y vit. C'est ainsi que fonctionnent la plupart des implémentations de langages comme Java, Python et JavaScript.

[go]: https://golang.org/

## Raccourcis et itinéraires alternatifs

Voilà le long chemin couvrant toutes les phases possibles que vous pourriez implémenter. Beaucoup de langages parcourent tout le chemin, mais il existe quelques raccourcis et chemins alternatifs.

### Compilateurs à passage unique

Certains compilateurs simples intercalent analyse syntaxique, analyse sémantique et génération de code pour produire directement du code de sortie dans le parseur, sans jamais allouer d'arbres syntaxiques ou d'autres IR. Ces <span name="sdt">**compilateurs à passage unique**</span> restreignent la conception du langage. Vous n'avez pas de structures de données intermédiaires pour stocker des informations globales sur le programme, et vous ne revisitez aucune partie déjà analysée du code. Cela signifie qu'au moment où vous voyez une expression, vous devez en savoir assez pour la compiler correctement.

<aside name="sdt">

[**Traduction dirigée par la syntaxe**][pass] est une technique structurée pour construire ces compilateurs « tout-en-un ». Vous associez une *action* à chaque partie de la grammaire, généralement une qui génère du code de sortie. Puis, chaque fois que le parseur reconnaît ce morceau de syntaxe, il exécute l'action, construisant le code cible règle par règle.

[pass]: https://en.wikipedia.org/wiki/Syntax-directed_translation

</aside>

Pascal et C ont été conçus autour de cette limitation. À l'époque, la mémoire était si précieuse qu'un compilateur ne pouvait même pas contenir un *fichier source* entier en mémoire, encore moins le programme complet. C'est pourquoi la grammaire de Pascal exige que les déclarations de type apparaissent en premier dans un bloc. C'est pourquoi, en C, vous ne pouvez pas appeler une fonction au-dessus du code qui la définit à moins d'avoir une déclaration anticipée explicite indiquant au compilateur ce qu'il doit savoir pour générer le code pour un appel à la fonction ultérieure.

### Interpréteurs par parcours d'arbre

Certains langages commencent à exécuter le code juste après l'avoir analysé en AST (avec peut-être un peu d'analyse statique appliquée). Pour exécuter le programme, l'interpréteur parcourt l'arbre syntaxique branche par branche et feuille par feuille, évaluant chaque nœud au fur et à mesure.

Ce style d'implémentation est courant pour les projets étudiants et les petits langages, mais n'est pas largement utilisé pour les langages <span name="ruby">généralistes</span> car il tend à être lent. Certaines personnes utilisent le terme « interpréteur » uniquement pour ce type d'implémentations, mais d'autres définissent ce mot de manière plus générale, donc j'utiliserai l'expression incontestablement explicite **interpréteur par parcours d'arbre** pour les désigner. Notre premier interpréteur fonctionne de cette manière.

<aside name="ruby">

Une exception notable est celle des premières versions de Ruby, qui étaient des parcours d'arbre. À la version 1.9, l'implémentation canonique de Ruby est passée de l'original MRI (Matz's Ruby Interpreter) au YARV de Koichi Sasada (Yet Another Ruby VM). YARV est une machine virtuelle à bytecode.

</aside>


### Transpileurs

<span name="gary">Écrire</span> un back-end complet pour un langage peut représenter beaucoup de travail. Si vous disposez déjà d'une IR générique à cibler, vous pourriez y raccorder votre front-end. Sinon, il semble que vous soyez coincé. Mais que se passerait-il si vous traitiez un autre *langage source* comme s'il s'agissait d'une représentation intermédiaire ?

Vous écrivez un front-end pour votre langage. Puis, dans le back-end, au lieu de faire tout le travail pour *abaisser* les sémantiques vers un langage cible primitif, vous produisez une chaîne de code source valide pour un autre langage à peu près aussi haut niveau que le vôtre. Ensuite, vous utilisez les outils de compilation existants pour *ce* langage comme échappatoire de la montagne pour descendre vers quelque chose que vous pouvez exécuter.

On appelait autrefois cela un **compilateur source-à-source** ou un **transcompilateur**. Après l'essor des langages qui se compilent en JavaScript pour s'exécuter dans le navigateur, le sobriquet hipster **transpileur** s'est imposé.

<aside name="gary">

Le premier transcompilateur, XLT86, traduisait l'assembleur 8080 en assembleur 8086. Cela peut sembler simple, mais gardez à l'esprit que le 8080 était une puce 8 bits et le 8086 une puce 16 bits pouvant utiliser chaque registre comme une paire de registres 8 bits. XLT86 effectuait une analyse des flux de données pour suivre l'utilisation des registres dans le programme source et les mapper efficacement à l'ensemble de registres du 8086.

Il a été écrit par Gary Kildall, un héros tragique de l'informatique s'il en fut un. L'un des premiers à reconnaître le potentiel des micro-ordinateurs, il a créé PL/M et CP/M, le premier langage de haut niveau et le premier OS pour ces machines.

C'était un capitaine de mer, chef d'entreprise, pilote agréé et motard. Un animateur TV avec le look à la Kris Kristofferson porté par les beaux barbus des années 80. Il a affronté Bill Gates et, comme beaucoup, a perdu, avant de rencontrer sa fin dans un bar de motards dans des circonstances mystérieuses. Il est mort trop jeune, mais il a certainement bien vécu avant cela.

</aside>

Alors que le premier transcompilateur traduisait un langage assembleur en un autre, aujourd'hui, la plupart des transpileurs travaillent sur des langages de plus haut niveau. Après la propagation virale d'UNIX sur diverses machines, une longue tradition de compilateurs produisant du C comme langage de sortie a commencé. Les compilateurs C étaient disponibles partout où UNIX était présent et produisaient un code efficace, donc cibler le C était un bon moyen de faire fonctionner votre langage sur de nombreuses architectures.

Les navigateurs web sont les "machines" d'aujourd'hui, et leur "code machine" est le JavaScript, donc de nos jours, il semble que [presque tous les langages existants][js] aient un compilateur ciblant JS puisque c'est le <span name="js">principal</span> moyen d'exécuter votre code dans un navigateur.

[js]: https://github.com/jashkenas/coffeescript/wiki/list-of-languages-that-compile-to-js

<aside name="js">

JS était autrefois le *seul* moyen d'exécuter du code dans un navigateur. Grâce à [WebAssembly][], les compilateurs disposent maintenant d'un second langage de bas niveau qu'ils peuvent cibler et qui s'exécute sur le web.

[webassembly]: https://github.com/webassembly/

</aside>

Le front-end -- scanner et parseur -- d'un transpileur ressemble à celui des autres compilateurs. Ensuite, si le langage source n'est qu'une simple couche syntaxique sur le langage cible, il peut ignorer complètement l'analyse et passer directement à la génération de la syntaxe équivalente dans le langage de destination.

Si les deux langages sont plus sémantiquement différents, vous verrez davantage de phases typiques d'un compilateur complet, y compris l'analyse et éventuellement l'optimisation. Puis, lorsqu'il s'agit de génération de code, au lieu de produire un langage binaire comme le code machine, vous produisez une chaîne de code source (en fait, destination) grammaticalement correcte dans le langage cible.

Dans tous les cas, vous passez ensuite ce code résultant dans le pipeline de compilation existant du langage de sortie, et le tour est joué.


### Compilation juste-à-temps

Cette dernière option est moins un raccourci qu'une escalade alpine dangereuse, mieux réservée aux experts. Le moyen le plus rapide d'exécuter du code est de le compiler en code machine, mais vous ne savez peut-être pas quelle architecture la machine de votre utilisateur final supporte. Que faire ?

Vous pouvez faire la même chose que la HotSpot Java Virtual Machine (JVM), le Common Language Runtime (CLR) de Microsoft et la plupart des interpréteurs JavaScript. Sur la machine de l'utilisateur final, lorsque le programme est chargé – soit à partir du code source dans le cas de JS, soit à partir d'un bytecode indépendant de la plateforme pour la JVM et le CLR – vous le compilez en code natif pour l'architecture que son ordinateur supporte. Naturellement, cela s'appelle **compilation juste-à-temps**. La plupart des hackers disent simplement "JIT", prononcé comme rime avec "fit".

Les JIT les plus sophistiqués insèrent des hooks de profilage dans le code généré pour voir quelles zones sont les plus critiques en termes de performance et quel type de données y circule. Ensuite, au fil du temps, ils recompilent automatiquement ces <span name="hot">points chauds</span> avec des optimisations plus avancées.

<aside name="hot">

C'est, bien sûr, exactement de là que la JVM HotSpot tire son nom.

</aside>

## Compilateurs et interpréteurs

Maintenant que je vous ai rempli la tête d'un dictionnaire de jargon sur les langages de programmation, nous pouvons enfin aborder une question qui tourmente les codeurs depuis la nuit des temps : Quelle est la différence entre un compilateur et un interpréteur ?

Il s'avère que c'est comme demander la différence entre un fruit et un légume. Cela semble être un choix binaire, mais en réalité, "fruit" est un terme *botanique* et "légume" est *culinaire*. L'un n'implique pas strictement la négation de l'autre. Il y a des fruits qui ne sont pas des légumes (pommes) et des légumes qui ne sont pas des fruits (carottes), mais aussi des plantes comestibles qui sont à la fois des fruits *et* des légumes, comme les tomates.

<span name="veg"></span>

<img src="image/a-map-of-the-territory/plants.png" alt="Diagramme de Venn des plantes comestibles" />

<aside name="veg">

Les arachides (qui ne sont même pas des noix) et les céréales comme le blé sont en réalité des fruits, mais j'ai mal dessiné ce diagramme. Que voulez-vous que je dise, je suis ingénieur logiciel, pas botaniste. Je devrais probablement effacer le petit arachide, mais il est tellement mignon que je n'y arrive pas.

Les *pignons de pin*, par contre, sont des aliments d'origine végétale qui ne sont ni des fruits ni des légumes. Du moins d'après ce que je peux dire.

</aside>

Revenons aux langages :

* **Compiler** est une *technique d'implémentation* qui consiste à traduire un langage source en une autre forme – généralement de bas niveau. Lorsque vous générez du bytecode ou du code machine, vous compilez. Lorsque vous transpilez vers un autre langage de haut niveau, vous compilez également.

* Lorsque nous disons qu'une implémentation de langage "est un **compilateur**", nous voulons dire qu'elle traduit le code source en une autre forme mais ne l'exécute pas. L'utilisateur doit prendre le résultat et l'exécuter lui-même.

* À l'inverse, lorsque nous disons qu'une implémentation "est un **interpréteur**", nous voulons dire qu'elle prend le code source et l'exécute immédiatement. Elle exécute les programmes "à partir du source".

Comme pour les pommes et les oranges, certaines implémentations sont clairement des compilateurs et *pas* des interpréteurs. GCC et Clang prennent votre code C et le compilent en code machine. L'utilisateur final exécute directement cet exécutable et peut ne jamais savoir quel outil a été utilisé pour le compiler. Ce sont donc des *compilateurs* pour le C.

Dans les versions plus anciennes de l'implémentation canonique de Ruby de Matz, l'utilisateur exécutait Ruby à partir du code source. L'implémentation le parseait et l'exécutait directement en parcourant l'arbre syntaxique. Aucune autre traduction ne se produisait, ni en interne ni sous une forme visible par l'utilisateur. C'était donc définitivement un *interpréteur* pour Ruby.

Mais qu'en est-il de CPython ? Lorsque vous exécutez votre programme Python avec lui, le code est analysé et converti en un format de bytecode interne, qui est ensuite exécuté dans la VM. Du point de vue de l'utilisateur, il s'agit clairement d'un interpréteur – ils exécutent leur programme à partir du code source. Mais si vous regardez sous la peau écailleuse de CPython, vous verrez qu'il y a définitivement un peu de compilation en cours.

La réponse est que c'est <span name="go">les deux</span>. CPython *est* un interpréteur, et il *possède* un compilateur. En pratique, la plupart des langages de script fonctionnent de cette manière, comme vous pouvez le constater :


<aside name="go">

L’[outil Go][go] est encore plus une curiosité horticole.  
Si vous exécutez `go build`, il compile votre code source Go en code machine et s’arrête.  
Si vous tapez `go run`, il fait cela, puis exécute immédiatement l’exécutable généré.  

Ainsi, `go` *est* un compilateur (vous pouvez l’utiliser comme un outil pour compiler du code sans l’exécuter),  
*est* un interpréteur (vous pouvez l’invoquer pour exécuter immédiatement un programme depuis le code source),  
et *contient* aussi un compilateur (quand vous l’utilisez comme interpréteur, il compile tout de même en interne).

[go tool]: https://golang.org/cmd/go/

</aside>

<img src="image/a-map-of-the-territory/venn.png" alt="Un diagramme de Venn des compilateurs et interprètes" />

La zone de chevauchement au centre est aussi l’endroit où vit notre second interpréteur,  
puisqu’il compile en interne vers du bytecode.  
Donc, même si ce livre est nominalement consacré aux interprètes,  
nous couvrirons aussi un peu de compilation.

## Notre voyage

Cela fait beaucoup d’informations à absorber d’un coup. Ne vous inquiétez pas.  
Ce n’est pas dans ce chapitre que vous êtes censé *comprendre* toutes ces pièces et parties.  
Je veux simplement que vous sachiez qu’elles existent et comment elles s’articulent grossièrement.  

Cette carte devrait vous être utile quand vous explorerez le territoire au-delà du chemin guidé que nous suivons ici.  
J’aimerais vous laisser avec l’envie de partir seul à l’aventure et d’errer partout sur cette montagne.  

Mais, pour l’instant, il est temps que notre propre voyage commence.  
Serrez vos lacets, ajustez votre sac, et venez avec moi.  
À partir de <span name="here">maintenant</span>, tout ce sur quoi vous devez vous concentrer, c’est le chemin juste devant vous.

<aside name="here">

Désormais, je promets d’atténuer un peu la métaphore de la montagne.

</aside>

<div class="challenges">

## Défis

1. Choisissez une implémentation open source d’un langage que vous aimez.  
   Téléchargez le code source et explorez-le.  
   Essayez de trouver le code qui implémente le scanner et l’analyseur syntaxique.  
   Sont-ils écrits à la main, ou générés avec des outils comme Lex et Yacc ?  
   (Les fichiers `.l` ou `.y` suggèrent généralement cette dernière option.)

2. La compilation juste-à-temps a tendance à être la manière la plus rapide d’implémenter des langages dynamiques,  
   mais tous ne l’utilisent pas. Quelles raisons peut-on avoir de *ne pas* utiliser le JIT ?

3. La plupart des implémentations de Lisp qui compilent vers du C contiennent aussi un interpréteur  
   leur permettant d’exécuter du code Lisp à la volée. Pourquoi ?

</div>
