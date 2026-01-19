> Si seulement l'on pouvait inventer quelque chose pour mettre les souvenirs en flacon, comme les parfums. Pour qu'ils ne se dissipent jamais, pour qu'ils ne s'éventent jamais. Et puis, quand on le voudrait, la bouteille pourrait être débouchée, et ce serait comme revivre le moment tout à nouveau.
>
> <cite>Daphne du Maurier, <em>Rebecca</em></cite>

Le [chapitre précédent][hash] était une longue exploration d'une grosse structure de données fondamentale, profonde de l'informatique. Lourd sur la théorie et le concept. Il peut y avoir eu quelques discussions sur la notation grand-O et les algorithmes. Ce chapitre a moins de prétentions intellectuelles. Il n'y a pas de grandes idées à apprendre. Au lieu de cela, c'est une poignée de tâches d'ingénierie directes. Une fois que nous les aurons complétées, notre machine virtuelle supportera les variables.

En fait, elle supportera seulement les variables _globales_. Les locales arrivent dans le [chapitre suivant][]. Dans jlox, nous avons réussi à les fourrer toutes les deux dans un seul chapitre parce que nous avons utilisé la même technique d'implémentation pour toutes les variables. Nous avons construit une chaîne d'environnements, un pour chaque portée, tout le chemin jusqu'au sommet. C'était un moyen simple et propre d'apprendre comment gérer l'état.

[next chapter]: variables-locales.html

Mais c'est aussi _lent_. Allouer une nouvelle table de hachage chaque fois que vous entrez dans un bloc ou appelez une fonction n'est pas la route vers une VM rapide. Étant donné combien de code est concerné par l'utilisation de variables, si les variables vont lentement, tout va lentement. Pour clox, nous améliorerons cela en utilisant une stratégie bien plus efficace pour les variables <span name="different">locales</span>, mais les globales ne sont pas aussi facilement optimisées.

<aside name="different">

C'est une méta-stratégie commune dans les implémentations de langage sophistiquées. Souvent, la même fonctionnalité de langage aura de multiples techniques d'implémentation, chacune réglée pour différents modèles d'utilisation. Par exemple, les VMs JavaScript ont souvent une représentation plus rapide pour les objets qui sont utilisés plus comme des instances de classes comparé à d'autres objets dont l'ensemble de propriétés est modifié plus librement. Les compilateurs C et C++ ont habituellement une variété de façons de compiler les instructions `switch` basées sur le nombre de cas et comment les valeurs de cas sont densément empaquetées.

</aside>

[hash]: tables-de-hachage.html

Un rafraîchissement rapide sur la sémantique de Lox : Les variables globales dans Lox sont "liées tardivement" (late bound), ou résolues dynamiquement. Cela signifie que vous pouvez compiler un morceau de code qui fait référence à une variable globale avant qu'elle soit définie. Tant que le code ne s'_exécute_ pas avant que la définition arrive, tout va bien. En pratique, cela signifie que vous pouvez faire référence à des variables ultérieures à l'intérieur du corps de fonctions.

```lox
fun showVariable() {
  print global;
}

var global = "after";
showVariable();
```

Du code comme celui-ci pourrait sembler étrange, mais c'est pratique pour définir des fonctions mutuellement récursives. Cela joue aussi plus gentiment avec le REPL. Vous pouvez écrire une petite fonction en une ligne, puis définir la variable qu'elle utilise dans la suivante.

Les variables locales fonctionnent différemment. Puisque la déclaration d'une variable locale se produit _toujours_ avant qu'elle soit utilisée, la VM peut les résoudre au moment de la compilation, même dans un simple compilateur à une passe. Cela nous laissera utiliser une représentation plus intelligente pour les locales. Mais c'est pour le chapitre suivant. Juste maintenant, inquiétons-nous seulement des globales.

## Instructions

Les variables viennent à l'existence en utilisant des déclarations de variable, ce qui signifie que maintenant est aussi le moment d'ajouter le support pour les instructions à notre compilateur. Si vous vous rappelez, Lox sépare les instructions en deux catégories. Les "Déclarations" sont ces instructions qui lient un nouveau nom à une valeur. Les autres sortes d'instructions -- contrôle de flux, print, etc. -- sont juste appelées "instructions". Nous interdisons les déclarations directement à l'intérieur des instructions de contrôle de flux, comme ceci :

```lox
if (monday) var croissant = "yes"; // Erreur.
```

Le permettre soulèverait des questions confuses autour de la portée de la variable. Donc, comme d'autres langages, nous l'interdisons syntaxiquement en ayant une règle de grammaire séparée pour le sous-ensemble d'instructions qui _sont_ permises à l'intérieur d'un corps de contrôle de flux.

```ebnf
statement      → exprStmt
               | forStmt
               | ifStmt
               | printStmt
               | returnStmt
               | whileStmt
               | block ;
```

Ensuite nous utilisons une règle séparée pour le niveau supérieur d'un script et à l'intérieur d'un bloc.

```ebnf
declaration    → classDecl
               | funDecl
               | varDecl
               | statement ;
```

La règle `declaration` contient les instructions qui déclarent des noms, et inclut aussi `statement` pour que tous les types d'instruction soient permis. Puisque `block` lui-même est dans `statement`, vous pouvez mettre des déclarations <span name="parens">à l'intérieur</span> d'une construction de contrôle de flux en les nichant à l'intérieur d'un bloc.

<aside name="parens">

Les blocs fonctionnent un peu comme les parenthèses le font pour les expressions. Un bloc vous laisse mettre les instructions de déclaration à "priorité plus basse" dans des endroits où seulement une instruction non déclarative à "priorité plus haute" est permise.

</aside>

Dans ce chapitre, nous couvrirons seulement une couple d'instructions et une déclaration.

```ebnf
statement      → exprStmt
               | printStmt ;

declaration    → varDecl
               | statement ;
```

Jusqu'à maintenant, notre VM considérait un "programme" comme étant une expression unique puisque c'est tout ce que nous pouvions analyser et compiler. Dans une implémentation complète de Lox, un programme est une séquence de déclarations. Nous sommes prêts à supporter cela maintenant.

^code compile (1 before, 1 after)

Nous continuons de compiler des déclarations jusqu'à ce que nous touchions la fin du fichier source. Nous compilons une déclaration unique en utilisant ceci :

^code declaration

Nous arriverons aux déclarations de variable plus tard dans le chapitre, donc pour l'instant, nous transférons simplement à `statement()`.

^code statement

Les blocs peuvent contenir des déclarations, et les instructions de contrôle de flux peuvent contenir d'autres instructions. Cela signifie que ces deux fonctions seront éventuellement récursives. Nous pouvons aussi bien écrire les déclarations anticipées maintenant.

^code forward-declarations (1 before, 1 after)

### Instructions Print

Nous avons deux types d'instruction à supporter dans ce chapitre. Commençons avec les instructions `print`, qui commencent, assez naturellement, avec un jeton `print`. Nous détectons cela en utilisant cette fonction aide :

^code match

Vous pouvez la reconnaître de jlox. Si le jeton courant a le type donné, nous consommons le jeton et renvoyons `true`. Sinon nous laissons le jeton tranquille et renvoyons `false`. Cette fonction <span name="turtles">aide</span> est implémentée en termes de cette autre aide :

<aside name="turtles">

Ce sont des aides tout le long !

</aside>

^code check

La fonction `check()` renvoie `true` si le jeton courant a le type donné. Cela semble un peu <span name="read">bête</span> d'envelopper ceci dans une fonction, mais nous l'utiliserons plus tard, et je pense que de courtes fonctions nommées par des verbes comme celle-ci rendent l'analyseur plus facile à lire.

<aside name="read">

Cela semble trivial, mais les analyseurs écrits à la main pour des langages non-jouets deviennent assez gros. Quand vous avez des milliers de lignes de code, une fonction utilitaire qui transforme deux lignes en une et rend le résultat un peu plus lisible gagne facilement son pain.

</aside>

Si nous avons bien correspondu au jeton `print`, alors nous compilons le reste de l'instruction ici :

^code print-statement

Une instruction `print` évalue une expression et imprime le résultat, donc nous analysons et compilons d'abord cette expression. La grammaire attend un point-virgule après cela, donc nous le consommons. Finalement, nous émettons une nouvelle instruction pour imprimer le résultat.

^code op-print (1 before, 1 after)

À l'exécution, nous exécutons cette instruction comme ceci :

^code interpret-print (1 before, 1 after)

Quand l'interpréteur atteint cette instruction, il a déjà exécuté le code pour l'expression, laissant la valeur résultat au sommet de la pile. Maintenant nous la dépilons simplement et l'imprimons.

Notez que nous ne poussons rien d'autre après cela. C'est une différence clé entre les expressions et les instructions dans la VM. Chaque instruction bytecode a un <span name="effect">**effet de pile**</span> qui décrit comment l'instruction modifie la pile. Par exemple, `OP_ADD` dépile deux valeurs et en empile une, laissant la pile un élément plus petit qu'avant.

<aside name="effect">

La pile est un élément plus courte après un `OP_ADD`, donc son effet est -1 :

<img src="image/global-variables/stack-effect.png" alt="L'effet de pile d'une instruction OP_ADD." />

</aside>

Vous pouvez sommer les effets de pile d'une série d'instructions pour obtenir leur effet total. Quand vous ajoutez les effets de pile de la série d'instructions compilées depuis n'importe quelle expression complète, cela totalisera un. Chaque expression laisse une valeur résultat sur la pile.

Le bytecode pour une instruction entière a un effet de pile total de zéro. Puisqu'une instruction ne produit aucune valeur, elle laisse ultimement la pile inchangée, bien qu'elle utilise bien sûr la pile pendant qu'elle fait son truc. C'est important parce que quand nous arriverons au contrôle de flux et aux boucles, un programme pourrait exécuter une longue série d'instructions. Si chaque instruction grandissait ou rétrécissait la pile, elle pourrait éventuellement déborder ou sous-déborder.

Pendant que nous sont dans la boucle de l'interpréteur, nous devrions supprimer un peu de code.

^code op-return (1 before, 1 after)

Quand la VM compilait et évaluait seulement une expression unique, nous avions du code temporaire dans `OP_RETURN` pour sortir la valeur. Maintenant que nous avons des instructions et `print`, nous n'avons plus besoin de ça. Nous sommes une <span name="return">étape</span> plus près de l'implémentation complète de clox.

<aside name="return">

Nous sommes seulement une étape plus près, cependant. Nous revisiterons `OP_RETURN` encore quand nous ajouterons les fonctions. Juste maintenant, elle sort de la boucle de l'interpréteur entière.

</aside>

Comme d'habitude, une nouvelle instruction a besoin de support dans le désassembleur.

^code disassemble-print (1 before, 1 after)

C'est notre instruction `print`. Si vous voulez, donnez-lui un essai :

```lox
print 1 + 2;
print 3 * 4;
```

Excitant ! OK, peut-être pas palpitant, mais nous pouvons construire des scripts qui contiennent autant d'instructions que nous voulons maintenant, ce qui ressemble à du progrès.

### Instructions d'expression

Attendez de voir la prochaine instruction. Si nous ne voyons _pas_ un mot-clé `print`, alors nous devons être en train de regarder une instruction d'expression.

^code parse-expressions-statement (1 before, 1 after)

C'est analysé comme ceci :

^code expression-statement

Une "instruction d'expression" est simplement une expression suivie par un point-virgule. C'est comment vous écrivez une expression dans un contexte où une instruction est attendue. Habituellement, c'est pour que vous puissiez appeler une fonction ou évaluer une affectation pour son effet de bord, comme ceci :

```lox
brunch = "quiche";
eat(brunch);
```

Sémantiquement, une instruction d'expression évalue l'expression et jette le résultat. Le compilateur encode directement ce comportement. Il compile l'expression, et ensuite émet une instruction `OP_POP`.

^code pop-op (1 before, 1 after)

Comme le nom l'implique, cette instruction dépile la valeur du sommet de la pile et l'oublie.

^code interpret-pop (1 before, 1 after)

Nous pouvons la désassembler aussi.

^code disassemble-pop (1 before, 1 after)

Les instructions d'expression ne sont pas très utiles encore puisque nous ne pouvons créer aucune expression qui a des effets de bord, mais elles seront essentielles quand nous [ajouterons les fonctions plus tard][functions]. La <span name="majority">majorité</span> des instructions dans du code du monde réel dans des langages comme C sont des instructions d'expression.

<aside name="majority">

D'après mon compte, 80 des 149 instructions, dans la version de "compiler.c" que nous avons à la fin de ce chapitre sont des instructions d'expression.

</aside>

[functions]: appels-et-fonctions.html

### Synchronisation d'erreur

Pendant que nous faisons ce travail initial dans le compilateur, nous pouvons nous occuper d'une affaire non résolue que nous avons laissée [plusieurs chapitres en arrière][errors]. Comme jlox, clox utilise la récupération d'erreur en mode panique pour minimiser le nombre d'erreurs de compilation en cascade qu'il rapporte. Le compilateur sort du mode panique quand il atteint un point de synchronisation. Pour Lox, nous avons choisi les frontières d'instruction comme point. Maintenant que nous avons des instructions, nous pouvons implémenter la synchronisation.

[errors]: compilation-des-expressions.html#gérer-les-erreurs-de-syntaxe

^code call-synchronize (1 before, 1 after)

Si nous touchons une erreur de compilation en analysant l'instruction précédente, nous entrons en mode panique. Quand cela arrive, après l'instruction nous commençons à synchroniser.

^code synchronize

Nous sautons les jetons indistinctement jusqu'à ce que nous atteignions quelque chose qui ressemble à une frontière d'instruction. Nous reconnaissons la frontière en cherchant un jeton précédent qui peut finir une instruction, comme un point-virgule. Ou nous chercherons un jeton ultérieur qui commence une instruction, habituellement un des mots-clés de contrôle de flux ou de déclaration.

## Déclarations de Variable

Être simplement capable d'_imprimer_ ne gagne aucun prix à votre langage à la <span name="fair">foire</span> aux langages de programmation, alors passons à quelque chose d'un peu plus ambitieux et mettons les variables en marche. Il y a trois opérations que nous avons besoin de supporter :

<aside name="fair">

Je ne peux pas m'empêcher d'imaginer une "foire aux langages" comme une sorte de truc campagnard. Des rangées de stands doublés de paille pleins de bébés langages se *meuh*glant et se *bêê*lant l'un à l'autre.

</aside>

- Déclarer une nouvelle variable en utilisant une instruction `var`.
- Accéder à la valeur d'une variable en utilisant une expression identifiant.
- Stocker une nouvelle valeur dans une variable existante en utilisant une expression d'affectation.

Nous ne pouvons faire aucune des deux dernières avant d'avoir quelques variables, donc nous commençons avec les déclarations.

^code match-var (1 before, 2 after)

La fonction d'analyse bouche-trou que nous avons esquissée pour la règle grammaticale de déclaration a une vraie production maintenant. Si nous correspondons à un jeton `var`, nous sautons ici :

^code var-declaration

Le mot-clé est suivi par le nom de la variable. C'est compilé par `parseVariable()`, à laquelle nous arriverons dans une seconde. Ensuite nous cherchons un `=` suivi par une expression initialisatrice. Si l'utilisateur n'initialise pas la variable, le compilateur l'initialise implicitement à <span name="nil">`nil`</span> en émettant une instruction `OP_NIL`. De toute façon, nous attendons que l'instruction soit terminée par un point-virgule.

<aside name="nil" class="bottom">

Essentiellement, le compilateur désucre une déclaration de variable comme :

```lox
var a;
```

en :

```lox
var a = nil;
```

Le code qu'il génère pour la première est identique à ce qu'il produit pour la dernière.

</aside>

Il y a deux nouvelles fonctions ici pour travailler avec les variables et les identifiants. Voici la première :

^code parse-variable (2 before)

Elle exige que le prochain jeton soit un identifiant, qu'elle consomme et envoie ici :

^code identifier-constant (2 before)

Cette fonction prend le jeton donné et ajoute son léxème à la table des constantes du fragment comme une chaîne. Elle renvoie ensuite l'index de cette constante dans la table des constantes.

Les variables globales sont cherchées _par nom_ à l'exécution. Cela signifie que la VM -- la boucle de l'interpréteur bytecode -- a besoin d'accéder au nom. Une chaîne entière est trop grosse pour fourrer dans le flux de bytecode comme opérande. Au lieu de cela, nous stockons la chaîne dans la table des constantes et l'instruction fait ensuite référence au nom par son index dans la table.

Cette fonction renvoie cet index tout le chemin jusqu'à `varDeclaration()` qui le remet plus tard à ici :

^code define-variable

<span name="helper">Ceci</span> sort l'instruction bytecode qui définit la nouvelle variable et stocke sa valeur initiale. L'index du nom de la variable dans la table des constantes est l'opérande de l'instruction. Comme d'habitude dans une VM à pile, nous émettons cette instruction en dernier. À l'exécution, nous exécutons le code pour l'initialisateur de la variable d'abord. Cela laisse la valeur sur la pile. Ensuite cette instruction prend cette valeur et la stocke au loin pour plus tard.

<aside name="helper">

Je sais que certaines de ces fonctions semblent assez inutiles en ce moment. Mais nous en tirerons plus de kilométrage alors que nous ajouterons plus de fonctionnalités de langage pour travailler avec les noms. Les déclarations de fonction et de classe déclarent toutes deux de nouvelles variables, et les expressions de variable et d'affectation y accèdent.

</aside>

Là-bas dans le runtime, nous commençons avec cette nouvelle instruction :

^code define-global-op (1 before, 1 after)

Grâce à notre table de hachage pratique, l'implémentation n'est pas trop dure.

^code interpret-define-global (1 before, 1 after)

Nous obtenons le nom de la variable depuis la table des constantes. Ensuite nous <span name="pop">prenons</span> la valeur du sommet de la pile et la stockons dans une table de hachage avec ce nom comme clé.

<aside name="pop">

Notez que nous ne _dépilons_ pas la valeur avant _après_ l'avoir ajoutée à la table de hachage. Cela assure que la VM peut toujours trouver la valeur si un ramasse-miettes est déclenché juste au milieu de son ajout à la table de hachage. C'est une possibilité distincte puisque la table de hachage exige une allocation dynamique quand elle redimensionne.

</aside>

Ce code ne vérifie pas pour voir si la clé est déjà dans la table. Lox est assez lâche avec les variables globales et vous laisse les redéfinir sans erreur. C'est utile dans une session REPL, donc la VM supporte cela en écrasant simplement la valeur si la clé se trouve être déjà dans la table de hachage.

Il y a une autre petite macro aide :

^code read-string (1 before, 1 after)

Elle lit un opérande d'un octet depuis le fragment de bytecode. Elle traite cela comme un index dans la table des constantes du fragment et renvoie la chaîne à cet index. Elle ne vérifie pas que la valeur _est_ une chaîne -- elle la caste juste indistinctement. C'est sûr parce que le compilateur n'émet jamais une instruction qui fait référence à une constante non-chaîne.

Parce que nous nous soucions de l'hygiène lexicale, nous indéfinissons aussi cette macro à la fin de la fonction interpret.

^code undef-read-string (1 before, 1 after)

Je continue de dire "la table de hachage", mais nous n'en avons pas réellement une encore. Nous avons besoin d'un endroit pour stocker ces globales. Puisque nous voulons qu'elles persistent aussi longtemps que clox tourne, nous les stockons juste dans la VM.

^code vm-globals (1 before, 1 after)

Comme nous l'avons fait avec la table des chaînes, nous avons besoin d'initialiser la table de hachage à un état valide quand la VM démarre.

^code init-globals (1 before, 1 after)

Et nous la <span name="tear">démolissons</span> quand nous sortons.

<aside name="tear">

Le processus libérera tout à la sortie, mais cela semble indigne d'exiger du système d'exploitation de nettoyer notre désordre.

</aside>

^code free-globals (1 before, 1 after)

Comme d'habitude, nous voulons être capables de désassembler la nouvelle instruction aussi.

^code disassemble-define-global (1 before, 1 after)

Et avec cela, nous pouvons définir des variables globales. Pas que les utilisateurs puissent _dire_ qu'ils l'ont fait, parce qu'ils ne peuvent pas réellement les _utiliser_. Donc réparons ça ensuite.

## Lecture des Variables

Comme dans chaque langage de programmation de tous les temps, nous accédons à la valeur d'une variable en utilisant son nom. Nous accrochons les jetons identifiants à l'analyseur d'expression ici :

^code table-identifier (1 before, 1 after)

Cela appelle cette nouvelle fonction d'analyseur :

^code variable-without-assign

Comme avec les déclarations, il y a une couple de minuscules fonctions aides qui semblent inutiles maintenant mais deviendront plus utiles dans les chapitres ultérieurs. Je promets.

^code read-named-variable

Ceci appelle la même fonction `identifierConstant()` d'avant pour prendre le jeton identifiant donné et ajouter son léxème à la table des constantes du fragment comme une chaîne. Tout ce qui reste est d'émettre une instruction qui charge la variable globale avec ce nom. Voici l'instruction :

^code get-global-op (1 before, 1 after)

Là-bas dans l'interpréteur, l'implémentation reflète `OP_DEFINE_GLOBAL`.

^code interpret-get-global (1 before, 1 after)

Nous tirons l'index de la table des constantes de l'opérande de l'instruction et obtenons le nom de la variable. Ensuite nous utilisons cela comme une clé pour chercher la valeur de la variable dans la table de hachage des globales.

Si la clé n'est pas présente dans la table de hachage, cela signifie que cette variable globale n'a jamais été définie. C'est une erreur d'exécution dans Lox, donc nous la rapportons et sortons de la boucle de l'interpréteur si cela arrive. Sinon, nous prenons la valeur et la poussons sur la pile.

^code disassemble-get-global (1 before, 1 after)

Un petit peu de désassemblage, et nous avons fini. Notre interpréteur est maintenant capable de faire tourner du code comme ceci :

```lox
var beverage = "cafe au lait";
var breakfast = "beignets with " + beverage;
print breakfast;
```

Il y a seulement une opération restante.

## Affectation

À travers ce livre, j'ai essayé de vous garder sur un chemin assez sûr et facile. Je n'évite pas les _problèmes_ durs, mais j'essaie de ne pas rendre les _solutions_ plus complexes qu'elles ont besoin de l'être. Hélas, d'autres choix de conception dans notre compilateur <span name="jlox">bytecode</span> rendent l'affectation ennuyeuse à implémenter.

<aside name="jlox">

Si vous vous rappelez, l'affectation était assez facile dans jlox.

</aside>

Notre VM bytecode utilise un compilateur à une passe. Il analyse et génère du bytecode à la volée sans aucun AST intermédiaire. Dès qu'il reconnaît un morceau de syntaxe, il émet du code pour lui. L'affectation ne s'ajuste pas naturellement à cela. Considérez :

```lox
menu.brunch(sunday).beverage = "mimosa";
```

Dans ce code, l'analyseur ne réalise pas que `menu.brunch(sunday).beverage` est la cible d'une affectation et pas une expression normale jusqu'à ce qu'il atteigne `=`, beaucoup de jetons après le premier `menu`. D'ici là, le compilateur a déjà émis du bytecode pour le truc entier.

Le problème n'est pas aussi grave qu'il pourrait paraître, cependant. Regardez comment l'analyseur voit cet exemple :

<img src="image/global-variables/setter.png" alt="L'instruction 'menu.brunch(sunday).beverage = &quot;mimosa&quot;', montrant que 'menu.brunch(sunday)' est une expression." />

Même si la partie `.beverage` ne doit pas être compilée comme une expression get, tout à la gauche du `.` est une expression, avec la sémantique d'expression normale. La partie `menu.brunch(sunday)` peut être compilée et exécutée comme d'habitude.

Heureusement pour nous, les seules différences sémantiques sur le côté gauche d'une affectation apparaissent à la toute fin la plus à droite des jetons, précédant immédiatement le `=`. Même si le receveur d'un setter peut être une expression arbitrairement longue, la partie dont le comportement diffère d'une expression get est seulement l'identifiant traînant, qui est juste avant le `=`. Nous n'avons pas besoin de beaucoup d'anticipation pour réaliser que `beverage` devrait être compilé comme une expression set et pas un getter.

Les variables sont encore plus faciles puisqu'elles sont juste un identifiant nu unique avant un `=`. L'idée alors est que juste _avant_ de compiler une expression qui peut aussi être utilisée comme une cible d'affectation, nous cherchons un jeton `=` ultérieur. Si nous en voyons un, nous le compilons comme une affectation ou un setter au lieu d'un accès de variable ou un getter.

Nous n'avons pas de setters dont nous inquiéter encore, donc tout ce que nous avons besoin de gérer sont les variables.

^code named-variable (1 before, 1 after)

Dans la fonction d'analyse pour les expressions identifiants, nous cherchons un signe égal après l'identifiant. Si nous en trouvons un, au lieu d'émettre du code pour un accès de variable, nous compilons la valeur affectée et ensuite émettons une instruction d'affectation.

C'est la dernière instruction que nous avons besoin d'ajouter dans ce chapitre.

^code set-global-op (1 before, 1 after)

Comme vous vous y attendriez, son comportement à l'exécution est similaire à définir une nouvelle variable.

^code interpret-set-global (1 before, 1 after)

La différence principale est ce qui arrive quand la clé n'existe pas déjà dans la table de hachage des globales. Si la variable n'a pas été définie encore, c'est une erreur d'exécution d'essayer de lui assigner. Lox [ne fait pas de déclaration de variable implicite][implicit].

<aside name="delete">

L'appel à `tableSet()` stocke la valeur dans la table des variables globales même si la variable n'était pas précédemment définie. Ce fait est visible dans une session REPL, puisqu'elle continue de tourner même après que l'erreur d'exécution a été rapportée. Donc nous prenons soin aussi de supprimer cette valeur zombie de la table.

</aside>

L'autre différence est que régler une variable ne dépile pas la valeur de la pile. Rappelez-vous, l'affectation est une expression, donc elle a besoin de laisser cette valeur là au cas où l'affectation est nichée à l'intérieur de quelque plus grande expression.

[implicit]: instructions-et-état.html#note-de-conception

Ajoutez un soupçon de désassemblage :

^code disassemble-set-global (2 before, 1 after)

Donc nous avons fini, pas vrai ? Eh bien... pas tout à fait. Nous avons fait une erreur ! Jetez un coup d'œil à :

```lox
a * b = c + d;
```

Selon la grammaire de Lox, `=` a la précédence la plus basse, donc cela devrait être analysé grossièrement comme :

<img src="image/global-variables/ast-good.png" alt="L'analyse attendue, comme '(a * b) = (c + d)'." />

Évidemment, `a * b` n'est pas une cible d'affectation <span name="do">valide</span>, donc cela devrait être une erreur de syntaxe. Mais voici ce que notre analyseur fait :

<aside name="do">

Ne serait-ce pas dingue si `a * b` _était_ une cible d'affectation valide, cependant ? Vous pourriez imaginer quelque langage algèbre-esque qui essayait de diviser la valeur affectée d'une manière raisonnable et de la distribuer à `a` et `b`... c'est probablement une idée terrible.

</aside>

1.  D'abord, `parsePrecedence()` analyse `a` en utilisant l'analyseur préfixe `variable()`.
1.  Après cela, il entre dans la boucle d'analyse infixe.
1.  Il atteint le `*` et appelle `binary()`.
1.  Cela appelle récursivement `parsePrecedence()` pour analyser l'opérande de main droite.
1.  Cela appelle `variable()` encore pour analyser `b`.
1.  À l'intérieur de cet appel à `variable()`, il cherche un `=` traînant. Il en voit un et analyse ainsi le reste de la ligne comme une affectation.

En d'autres termes, l'analyseur voit le code ci-dessus comme :

<img src="image/global-variables/ast-bad.png" alt="L'analyse réelle, comme 'a * (b = c + d)'." />

Nous avons gâché la gestion de précédence parce que `variable()` ne prend pas en compte la précédence de l'expression environnante qui contient la variable. Si la variable se trouve être le côté main droite d'un opérateur infixe, ou l'opérande d'un opérateur unaire, alors cette expression contenante est de trop haute précédence pour permettre le `=`.

Pour réparer cela, `variable()` devrait chercher et consommer le `=` seulement s'il est dans le contexte d'une expression à basse précédence. Le code qui connaît la précédence courante est, assez logiquement, `parsePrecedence()`. La fonction `variable()` n'a pas besoin de connaître le niveau réel. Elle se soucie juste que la précédence soit assez basse pour permettre l'affectation, donc nous passons ce fait dedans comme un Booléen.

^code prefix-rule (4 before, 2 after)

Puisque l'affectation est l'expression à la plus basse précédence, la seule fois où nous permettons une affectation est quand nous analysons une expression d'affectation ou une expression de niveau supérieur comme dans une instruction d'expression. Ce drapeau fait son chemin vers la fonction analyseur ici :

^code variable

Qui le passe à travers un nouveau paramètre :

^code named-variable-signature (1 after)

Et ensuite l'utilise finalement ici :

^code named-variable-can-assign (2 before, 1 after)

C'est beaucoup de plomberie pour obtenir littéralement un bit de donnée au bon endroit dans le compilateur, mais arrivé il est. Si la variable est nichée à l'intérieur de quelque expression avec une précédence plus haute, `canAssign` sera `false` et cela ignorera le `=` même s'il y en a un là. Ensuite `namedVariable()` renvoie, et l'exécution fait éventuellement son chemin en retour vers `parsePrecedence()`.

Et alors ? Que fait le compilateur avec notre exemple cassé d'avant ? Juste maintenant, `variable()` ne consommera pas le `=`, donc ce sera le jeton courant. Le compilateur renvoie en retour vers `parsePrecedence()` depuis l'analyseur préfixe `variable()` et essaie ensuite d'entrer dans la boucle d'analyse infixe. Il n'y a pas de fonction d'analyse associée avec `=`, donc il saute cette boucle.

Ensuite `parsePrecedence()` renvoie silencieusement en retour vers l'appelant. Cela n'est pas juste non plus. Si le `=` ne se fait pas consommer comme partie de l'expression, rien d'autre ne va le consommer. C'est une erreur et nous devrions la rapporter.

^code invalid-assign (2 before, 1 after)

Avec cela, le programme mauvais précédent obtient correctement une erreur au moment de la compilation. OK, _maintenant_ avons-nous fini ? Toujours pas tout à fait. Voyez, nous passons un argument à une des fonctions d'analyse. Mais ces fonctions sont stockées dans une table de pointeurs de fonction, donc toutes les fonctions d'analyse ont besoin d'avoir le même type. Même si la plupart des fonctions d'analyse ne supportent pas d'être utilisées comme une cible d'affectation -- les setters sont la <span name="index">seule</span> autre -- notre compilateur C amical exige qu'elles acceptent _toutes_ le paramètre.

<aside name="index">

Si Lox avait des tableaux et des opérateurs indice comme `array[index]` alors un `[` infixe permettrait aussi l'affectation pour supporter `array[index] = value`.

</aside>

Donc nous allons finir ce chapitre avec un peu de sale boulot. D'abord, allons de l'avant et passons le drapeau aux fonctions d'analyse infixes.

^code infix-rule (1 before, 1 after)

Nous aurons besoin de ça pour les setters éventuellement. Ensuite nous réparerons le typedef pour le type de fonction.

^code parse-fn-type (2 before, 2 after)

Et un peu de code complètement ennuyeux pour accepter ce paramètre dans toutes nos fonctions d'analyse existantes. Ici :

^code binary (1 after)

Et ici :

^code parse-literal (1 after)

Et ici :

^code grouping (1 after)

Et ici :

^code number (1 after)

Et ici aussi :

^code string (1 after)

Et, finalement :

^code unary (1 after)

Ouf ! Nous sommes de retour à un programme C que nous pouvons compiler. Démarrez-le et maintenant vous pouvez faire tourner ceci :

```lox
var breakfast = "beignets";
var beverage = "cafe au lait";
breakfast = "beignets with " + beverage;

print breakfast;
```

Cela commence à ressembler à du vrai code pour un langage réel !

<div class="challenges">

## Défis

1.  Le compilateur ajoute le nom d'une variable globale à la table des constantes comme une chaîne chaque fois qu'un identifiant est rencontré. Il crée une nouvelle constante chaque fois, même si ce nom de variable est déjà dans un emplacement précédent dans la table des constantes. C'est gaspilleur dans les cas où la même variable est référencée de multiples fois par la même fonction. Cela, à son tour, augmente les chances de remplir la table des constantes et de tomber à court d'emplacements puisque nous permettons seulement 256 constantes dans un fragment unique.

    Optimisez cela. Comment votre optimisation affecte-t-elle la performance du compilateur comparée au runtime ? Est-ce le bon compromis ?

2.  Chercher une variable globale par nom dans une table de hachage chaque fois qu'elle est utilisée est assez lent, même avec une bonne table de hachage. Pouvez-vous trouver un moyen plus efficace de stocker et accéder aux variables globales sans changer la sémantique ?

3.  En tournant dans le REPL, un utilisateur pourrait écrire une fonction qui fait référence à une variable globale inconnue. Ensuite, dans la ligne suivante, il déclare la variable. Lox devrait gérer cela gracieusement en ne rapportant pas une erreur de compilation "variable inconnue" quand la fonction est d'abord définie.

    Mais quand un utilisateur fait tourner un _script_ Lox, le compilateur a accès au texte complet du programme entier avant que du code soit tourné. Considérez ce programme :

    ```lox
    fun useVar() {
      print oops;
    }

    var ooops = "too many o's!";
    ```

    Ici, nous pouvons dire statiquement que `oops` ne sera pas définie parce qu'il n'y a _aucune_ déclaration de cette globale nulle part dans le programme. Notez que `useVar()` n'est jamais appelée non plus, donc même si la variable n'est pas définie, aucune erreur d'exécution ne se produira parce qu'elle n'est jamais utilisée non plus.

    Nous pourrions rapporter des erreurs comme celle-ci comme des erreurs de compilation, au moins en tournant depuis un script. Pensez-vous que nous devrions ? Justifiez votre réponse. Que font d'autres langages de script que vous connaissez ?

</div>
