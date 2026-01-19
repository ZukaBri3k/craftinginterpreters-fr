> Toute ma vie, mon cœur a aspiré à une chose que je ne peux nommer.
> <cite>André Breton, <em>L'Amour fou</em></cite>

L'interpréteur que nous avons jusqu'ici ressemble moins à la programmation d'un vrai langage et plus à tapoter des boutons sur une calculatrice. "Programmer" pour moi signifie construire un système à partir de plus petits morceaux. Nous ne pouvons pas encore faire cela car nous n'avons aucun moyen de lier un nom à une donnée ou une fonction. Nous ne pouvons pas composer de logiciel sans un moyen de faire référence aux morceaux.

Pour supporter les liaisons (bindings), notre interpréteur a besoin d'un état interne. Quand vous définissez une variable au début du programme et l'utilisez à la fin, l'interpréteur doit conserver la valeur de cette variable entre-temps. Donc dans ce chapitre, nous allons donner à notre interpréteur un cerveau qui peut non seulement traiter, mais _se souvenir_.

<img src="image/statements-and-state/brain.png" alt="Un cerveau, se souvenant probablement de trucs." />

L'état et les <span name="expr">instructions</span> (statements) vont main dans la main. Puisque les instructions, par définition, ne s'évaluent pas en une valeur, elles doivent faire quelque chose d'autre pour être utiles. Ce quelque chose est appelé un **effet de bord**. Cela peut signifier produire une sortie visible par l'utilisateur ou modifier un état dans l'interpréteur qui pourra être détecté plus tard. Ce dernier en fait un excellent candidat pour définir des variables ou d'autres entités nommées.

<aside name="expr">

Vous pourriez faire un langage qui traite les déclarations de variables comme des expressions qui créent à la fois une liaison et produisent une valeur. Le seul langage que je connaisse qui fait cela est Tcl. Scheme semble être un candidat, mais notez qu'après qu'une expression `let` soit évaluée, la variable qu'elle liait est oubliée. La syntaxe `define` n'est pas une expression.

</aside>

Dans ce chapitre, nous allons faire tout cela. Nous définirons des instructions qui produisent une sortie (`print`) et créent un état (`var`). Nous ajouterons des expressions pour accéder aux variables et leur assigner une valeur. Enfin, nous ajouterons les blocs et la portée locale. C'est beaucoup à bourrer dans un seul chapitre, mais nous allons mâcher tout cela une bouchée à la fois.

## Instructions

Nous commençons par étendre la grammaire de Lox avec des instructions. Elles ne sont pas très différentes des expressions. Nous commençons avec les deux types les plus simples :

1.  Une **instruction d'expression** vous permet de placer une expression là où une instruction est attendue. Elles existent pour évaluer des expressions qui ont des effets de bord. Vous ne les remarquez peut-être pas, mais vous les utilisez tout le temps en <span name="expr-stmt">C</span>, Java, et d'autres langages. Chaque fois que vous voyez un appel de fonction ou de méthode suivi d'un `;`, vous regardez une instruction d'expression.

    <aside name="expr-stmt">

    Pascal est un cas à part. Il distingue entre _procédures_ et _fonctions_. Les fonctions renvoient des valeurs, mais les procédures ne le peuvent pas. Il y a une forme d'instruction pour appeler une procédure, mais les fonctions peuvent seulement être appelées là où une expression est attendue. Il n'y a pas d'instructions d'expression en Pascal.

    </aside>

2.  Une **instruction `print`** évalue une expression et affiche le résultat à l'utilisateur. J'admets que c'est bizarre d'intégrer l'impression directement dans le langage au lieu d'en faire une fonction de bibliothèque. Faire ainsi est une concession au fait que nous construisons cet interpréteur un chapitre à la fois et voulons être capables de jouer avec avant qu'il ne soit tout fini. Pour faire de print une fonction de bibliothèque, nous devrions attendre jusqu'à ce que nous ayons toute la machinerie pour définir et appeler des fonctions <span name="print">avant</span> que nous puissions témoigner du moindre effet de bord.

    <aside name="print">

    Je noterai avec seulement un soupçon de défensive que BASIC et Python ont des instructions `print` dédiées et ce sont de vrais langages. C'est vrai, Python a retiré son instruction `print` en 3.0...

    </aside>

Une nouvelle syntaxe signifie de nouvelles règles de grammaire. Dans ce chapitre, nous gagnons enfin la capacité de parser un script Lox entier. Puisque Lox est un langage impératif, typé dynamiquement, le "niveau supérieur" d'un script est simplement une liste d'instructions. Les nouvelles règles sont :

```ebnf
program        → statement* EOF ;

statement      → exprStmt
               | printStmt ;

exprStmt       → expression ";" ;
printStmt      → "print" expression ";" ;
```

La première règle est maintenant `program`, qui est le point de départ pour la grammaire et représente un script Lox complet ou une entrée REPL. Un programme est une liste d'instructions suivie par le token spécial "fin de fichier" (EOF). Le token de fin obligatoire assure que le parseur consomme l'entrée entière et n'ignore pas silencieusement des tokens non consommés erronés à la fin d'un script.

Pour l'instant, `statement` a seulement deux cas pour les deux types d'instructions que nous avons décrits. Nous en remplirons plus plus tard dans ce chapitre et dans les suivants. L'étape suivante est de transformer cette grammaire en quelque chose que nous pouvons stocker en mémoire -- des arbres syntaxiques.

### Arbres syntaxiques d'instruction

Il n'y a aucun endroit dans la grammaire où à la fois une expression et une instruction sont autorisées. Les opérandes de, disons, `+` sont toujours des expressions, jamais des instructions. Le corps d'une boucle `while` est toujours une instruction.

Puisque les deux syntaxes sont disjointes, nous n'avons pas besoin d'une seule classe de base dont elles héritent toutes. Séparer les expressions et les instructions dans des hiérarchies de classes séparées permet au compilateur Java de nous aider à trouver des erreurs bêtes comme passer une instruction à une méthode Java qui attend une expression.

Cela signifie une nouvelle classe de base pour les instructions. Comme nos aînés l'ont fait avant nous, nous utiliserons le nom cryptique "Stmt". Avec une grande <span name="foresight">prévoyance</span>, j'ai conçu notre petit script de métaprogrammation AST en anticipation de cela. C'est pourquoi nous avons passé "Expr" comme paramètre à `defineAst()`. Maintenant nous ajoutons un autre appel pour définir Stmt et ses <span name="stmt-ast">sous-classes</span>.

<aside name="foresight">

Pas vraiment de la prévoyance : j'ai écrit tout le code pour le livre avant de le découper en chapitres.

</aside>

^code stmt-ast (2 before, 1 after)

<aside name="stmt-ast">

Le code généré pour les nouveaux nœuds est dans l'[Annexe II][appendix-ii] : [Instruction d'expression][expression statement], [Instruction print][print statement].

[appendix-ii]: appendix-ii.html
[expression statement]: appendix-ii.html#expression-statement
[print statement]: appendix-ii.html#print-statement

</aside>

Exécutez le script générateur d'AST et contemplez le fichier "Stmt.java" résultant avec les classes d'arbre syntaxique dont nous avons besoin pour l'expression et les instructions `print`. N'oubliez pas d'ajouter le fichier à votre projet IDE ou makefile ou peu importe.

### Parser les instructions

La méthode `parse()` du parseur qui parse et renvoie une seule expression était un hack temporaire pour avoir le dernier chapitre opérationnel. Maintenant que notre grammaire a la règle de départ correcte, `program`, nous pouvons transformer `parse()` en la vraie affaire.

^code parse

<aside name="parse-error-handling">

Qu'en est-il du code que nous avions ici pour attraper les exceptions `ParseError` ? Nous mettrons une meilleure gestion d'erreur de parsing en place bientôt quand nous ajouterons le support pour des types d'instruction supplémentaires.

</aside>

Ceci parse une série d'instructions, autant qu'il peut en trouver jusqu'à ce qu'il frappe la fin de l'entrée. C'est une traduction assez directe de la règle `program` en style descente récursive. Nous devons aussi chanter une prière mineure aux dieux de la verbosité Java puisque nous utilisons ArrayList maintenant.

^code parser-imports (2 before, 1 after)

Un programme est une liste d'instructions, et nous parsons une de ces instructions en utilisant cette méthode :

^code parse-statement

Un peu squelettique, mais nous le remplirons avec plus de types d'instruction plus tard. Nous déterminons quelle règle d'instruction spécifique est matchée en regardant le token courant. Un token `print` signifie que c'est évidemment une instruction `print`.

Si le prochain token ne ressemble à aucun type connu d'instruction, nous supposons que ce doit être une instruction d'expression. C'est le cas par défaut typique final lors du parsing d'une instruction, puisqu'il est difficile de reconnaître proactivement une expression à partir de son premier token.

Chaque type d'instruction obtient sa propre méthode. D'abord `print` :

^code parse-print-statement

Puisque nous avons déjà matché et consommé le token `print` lui-même, nous n'avons pas besoin de faire cela ici. Nous parsons l'expression subséquente, consommons le point-virgule terminal, et émettons l'arbre syntaxique.

Si nous n'avons pas matché une instruction `print`, nous devons avoir une de celles-ci :

^code parse-expression-statement

Similaire à la méthode précédente, nous parsons une expression suivie par un point-virgule. Nous enveloppons cette Expr dans une Stmt du bon type et la renvoyons.

### Exécuter les instructions

Nous parcourons les quelques chapitres précédents en microcosme, en faisant notre chemin à travers le front end. Notre parseur peut maintenant produire des arbres syntaxiques d'instruction, donc la prochaine et dernière étape est de les interpréter. Comme dans les expressions, nous utilisons le patron Visiteur, mais nous avons une nouvelle interface visiteur, Stmt.Visitor, à implémenter puisque les instructions ont leur propre classe de base.

Nous ajoutons cela à la liste des interfaces que Interpreter implémente.

^code interpreter (1 after)

<aside name="void">

Java ne vous laisse pas utiliser le "void" minuscule comme argument de type générique pour des raisons obscures ayant à voir avec l'effacement de type (type erasure) et la pile. Au lieu de cela, il y a un type "Void" séparé spécifiquement pour cet usage. Sorte de "void boxé", comme "Integer" l'est pour "int".

</aside>

Contrairement aux expressions, les instructions ne produisent aucune valeur, donc le type de retour des méthodes visit est Void, pas Object. Nous avons deux types d'instruction, et nous avons besoin d'une méthode visit pour chaque. La plus facile est les instructions d'expression.

^code visit-expression-stmt

Nous évaluons l'expression interne en utilisant notre méthode `evaluate()` existante et <span name="discard">rejetons</span> la valeur. Ensuite nous renvoyons `null`. Java exige cela pour satisfaire le type de retour spécial Void avec majuscule. Bizarre, mais que pouvez-vous faire ?

<aside name="discard">

De manière assez appropriée, nous rejetons la valeur renvoyée par `evaluate()` en plaçant cet appel à l'intérieur d'une instruction d'expression _Java_.

</aside>

La méthode visit de l'instruction `print` n'est pas très différente.

^code visit-print

Avant de rejeter la valeur de l'expression, nous la convertissons en une chaîne en utilisant la méthode `stringify()` que nous avons introduite dans le dernier chapitre et ensuite la déversons sur la sortie standard (stdout).

Notre interpréteur est capable de visiter des instructions maintenant, mais nous avons un peu de travail à faire pour les lui donner à manger. D'abord, modifiez la vieille méthode `interpret()` dans la classe Interpreter pour accepter une liste d'instructions -- en d'autres termes, un programme.

^code interpret

Ceci remplace l'ancien code qui prenait une seule expression. Le nouveau code repose sur cette minuscule méthode d'aide :

^code execute

C'est l'analogue pour l'instruction de la méthode `evaluate()` que nous avons pour les expressions. Puisque nous travaillons avec des listes maintenant, nous avons besoin de le faire savoir à Java.

^code import-list (2 before, 2 after)

La classe principale Lox essaie toujours de parser une seule expression et de la passer à l'interpréteur. Nous corrigeons la ligne de parsing comme ceci :

^code parse-statements (1 before, 2 after)

Et ensuite remplaçons l'appel à l'interpréteur par ceci :

^code interpret-statements (2 before, 1 after)

Fondamentalement juste faire passer la nouvelle syntaxe dans la tuyauterie. OK, démarrez l'interpréteur et donnez-lui un essai. À ce stade, cela vaut la peine d'esquisser un petit programme Lox dans un fichier texte pour l'exécuter comme un script. Quelque chose comme :

```lox
print "un";
print true;
print 2 + 1;
```

Cela ressemble presque à un vrai programme ! Notez que le REPL, aussi, exige maintenant que vous entriez une instruction complète au lieu d'une simple expression. N'oubliez pas vos points-virgules.

## Variables Globales

Maintenant que nous avons des instructions, nous pouvons commencer à travailler sur l'état. Avant que nous entrions dans toute la complexité de la portée lexicale, nous commencerons avec le type le plus facile de variables -- les <span name="globals">globales</span>. Nous avons besoin de deux nouvelles constructions.

1.  Une instruction de **déclaration de variable** amène une nouvelle variable au monde.

    ```lox
    var beverage = "espresso";
    ```

    Ceci crée une nouvelle liaison qui associe un nom (ici "beverage") avec une valeur (ici, la chaîne `"espresso"`).

2.  Une fois que c'est fait, une **expression de variable** accède à cette liaison. Quand l'identifiant "beverage" est utilisé comme une expression, il cherche la valeur liée à ce nom et la renvoie.

    ```lox
    print beverage; // "espresso".
    ```

Plus tard, nous ajouterons l'affectation et la portée de bloc, mais c'est assez pour commencer à bouger.

<aside name="globals">

L'état global a mauvaise réputation. Bien sûr, beaucoup d'état global -- surtout l'état _mutable_ -- rend difficile la maintenance de gros programmes. C'est une bonne ingénierie logicielle de minimiser combien vous en utilisez.

Mais quand vous bricolez un langage de programmation simple ou, zut, même apprenez votre premier langage, la simplicité plate des variables globales aide. Mon premier langage était le BASIC et, bien que je l'ai dépassé finalement, c'était agréable que je n'aie pas à me prendre la tête avec les règles de portée avant que je puisse faire faire des trucs amusants à un ordinateur.

</aside>

### Syntaxe de variable

Comme avant, nous travaillerons à travers l'implémentation de l'avant vers l'arrière, en commençant par la syntaxe. Les déclarations de variable sont des instructions, mais elles sont différentes des autres instructions, et nous allons diviser la grammaire des instructions en deux pour les gérer. C'est parce que la grammaire restreint où certains types d'instructions sont autorisés.

Les clauses dans les instructions de contrôle de flux -- pensez aux branches then et else d'une instruction `if` ou le corps d'un `while` -- sont chacune une instruction unique. Mais cette instruction n'est pas autorisée à être une qui déclare un nom. Ceci est OK :

```lox
if (monday) print "Ugh, déjà ?";
```

Mais ceci ne l'est pas :

```lox
if (monday) var beverage = "espresso";
```

Nous _pourrions_ autoriser ce dernier, mais c'est confus. Quelle est la portée de cette variable `beverage` ? Persiste-t-elle après l'instruction `if` ? Si oui, quelle est sa valeur les jours autres que lundi ? La variable existe-t-elle tout court ces jours-là ?

Du code comme celui-ci est bizarre, donc C, Java, et consorts l'interdisent tous. C'est comme s'il y avait deux niveaux de <span name="brace">"précédence"</span> pour les instructions. Certains endroits où une instruction est autorisée -- comme à l'intérieur d'un bloc ou au niveau supérieur -- autorisent n'importe quel type d'instruction, y compris les déclarations. D'autres autorisent seulement les instructions de "plus haute" précédence qui ne déclarent pas de noms.

<aside name="brace">

Dans cette analogie, les instructions de bloc fonctionnent un peu comme les parenthèses pour les expressions. Un bloc est lui-même dans le niveau de précédence "plus haut" et peut être utilisé n'importe où, comme dans les clauses d'une instruction `if`. Mais les instructions qu'il _contient_ peuvent être de plus basse précédence. Vous êtes autorisé à déclarer des variables et d'autres noms à l'intérieur du bloc. Les accolades vous laissent vous échapper de nouveau vers la grammaire d'instructions complète depuis un endroit où seules certaines instructions sont autorisées.

</aside>

Pour accommoder la distinction, nous ajoutons une autre règle pour les types d'instructions qui déclarent des noms.

```ebnf
program        → declaration* EOF ;

declaration    → varDecl
               | statement ;

statement      → exprStmt
               | printStmt ;
```

Les instructions de déclaration vont sous la nouvelle règle `declaration`. Pour l'instant, c'est seulement les variables, mais plus tard cela inclura les fonctions et les classes. N'importe quel endroit où une déclaration est autorisée permet aussi les instructions non-déclarantes, donc la règle `declaration` tombe vers `statement`. Évidemment, vous pouvez déclarer des trucs au niveau supérieur d'un script, donc `program` route vers la nouvelle règle.

La règle pour déclarer une variable ressemble à :

```ebnf
varDecl        → "var" IDENTIFIER ( "=" expression )? ";" ;
```

Comme la plupart des instructions, elle commence par un mot-clé de tête. Dans ce cas, `var`. Ensuite un token identifiant pour le nom de la variable étant déclarée, suivi par une expression d'initialisation optionnelle. Finalement, nous mettons un nœud dessus avec le point-virgule.

Pour accéder à une variable, nous définissons un nouveau type d'expression primaire.

```ebnf
primary        → "true" | "false" | "nil"
               | NUMBER | STRING
               | "(" expression ")"
               | IDENTIFIER ;
```

Cette clause `IDENTIFIER` matche un seul token identifiant, qui est compris comme être le nom de la variable à laquelle on accède.

Ces nouvelles règles de grammaire obtiennent leurs arbres syntaxiques correspondants. Là-bas dans le générateur d'AST, nous ajoutons un <span name="var-stmt-ast">nouveau nœud d'instruction</span> pour une déclaration de variable.

^code var-stmt-ast (1 before, 1 after)

<aside name="var-stmt-ast">

Le code généré pour le nouveau nœud est dans l'[Annexe II][appendix-var-stmt].

[appendix-var-stmt]: appendix-ii.html#variable-statement

</aside>

Il stocke le token de nom pour que nous sachions ce qu'il déclare, avec l'expression d'initialisation. (S'il n'y a pas d'initialiseur, ce champ est `null`.)

Puis nous ajoutons un nœud d'expression pour accéder à une variable.

^code var-expr (1 before, 1 after)

<span name="var-expr-ast">C'est</span> simplement une enveloppe autour du token pour le nom de la variable. C'est tout. Comme toujours, n'oubliez pas d'exécuter le script générateur d'AST pour que vous obteniez des fichiers "Expr.java" et "Stmt.java" mis à jour.

<aside name="var-expr-ast">

Le code généré pour le nouveau nœud est dans l'[Annexe II][appendix-var-expr].

[appendix-var-expr]: appendix-ii.html#variable-expression

</aside>

### Parser les variables

Avant de parser les instructions de variable, nous avons besoin de bouger un peu de code pour faire de la place pour la nouvelle règle `declaration` dans la grammaire. Le niveau supérieur d'un programme est maintenant une liste de déclarations, donc la méthode point d'entrée vers le parseur change.

^code parse-declaration (3 before, 4 after)

Cela appelle cette nouvelle méthode :

^code declaration

Hé, vous souvenez-vous loin en arrière dans ce [chapitre précédent][parsing] quand nous avons mis l'infrastructure en place pour faire la récupération d'erreur ? Nous sommes enfin prêts à brancher cela.

[parsing]: parsing-expressions.html
[error recovery]: parsing-expressions.html#panic-mode-error-recovery

Cette méthode `declaration()` est la méthode que nous appelons de manière répétée lors du parsing d'une série d'instructions dans un bloc ou un script, donc c'est le bon endroit pour synchroniser quand le parseur entre en mode panique. Tout le corps de cette méthode est enveloppé dans un bloc try pour attraper l'exception lancée quand le parseur commence la récupération d'erreur. Cela le ramène à essayer de parser le début de l'instruction ou déclaration suivante.

Le vrai parsing se passe à l'intérieur du bloc try. D'abord, il regarde pour voir si nous sommes à une déclaration de variable en cherchant le mot-clé `var` de tête. Si non, il tombe dans la méthode `statement()` existante qui parse `print` et les instructions d'expression.

Rappelez-vous comment `statement()` essaie de parser une instruction d'expression si aucune autre instruction ne matche ? Et `expression()` rapporte une erreur de syntaxe si elle ne peut pas parser une expression au token courant ? Cette chaîne d'appels assure que nous rapportons une erreur si une déclaration ou instruction valide n'est pas parsée.

Quand le parseur matche un token `var`, il branche vers :

^code parse-var-declaration

Comme toujours, le code de descente récursive suit la règle de grammaire. Le parseur a déjà matché le token `var`, donc ensuite il exige et consomme un token identifiant pour le nom de la variable.

Puis, s'il voit un token `=`, il sait qu'il y a une expression d'initialisation et la parse. Sinon, il laisse l'initialiseur à `null`. Finalement, il consomme le point-virgule requis à la fin de l'instruction. Tout cela est enveloppé dans un nœud d'arbre syntaxique Stmt.Var et nous sommes groovy.

Parser une expression de variable est encore plus facile. Dans `primary()`, nous cherchons un token identifiant.

^code parse-identifier (2 before, 2 after)

Cela nous donne un front end fonctionnel pour déclarer et utiliser des variables. Tout ce qui reste est de le donner à manger à l'interpréteur. Avant que nous arrivions à cela, nous devons parler de l'endroit où les variables vivent en mémoire.

## Environnements

Les liaisons qui associent des variables à des valeurs ont besoin d'être stockées quelque part. Depuis que les gens de Lisp ont inventé les parenthèses, cette structure de données a été appelée un <span name="env">**environnement**</span>.

<img src="image/statements-and-state/environment.png" alt="Un environnement contenant deux liaisons." />

<aside name="env">

J'aime imaginer l'environnement littéralement, comme un pays des merveilles sylvestre où les variables et les valeurs gambadent.

</aside>

Vous pouvez penser à cela comme une <span name="map">map</span> où les clés sont les noms de variables et les valeurs sont les valeurs de la variable, euh, valeurs. En fait, c'est comme ça que nous l'implémenterons en Java. Nous pourrions fourrer cette map et le code pour la gérer directement dans Interpreter, mais puisqu'elle forme un concept joliment délimité, nous la sortirons dans sa propre classe.

Commencez un nouveau fichier et ajoutez :

<aside name="map">

Java les appelle **maps** ou **hashmaps**. D'autres langages les appellent **tables de hachage**, **dictionnaires** (Python et C#), **hashes** (Ruby et Perl), **tables** (Lua), ou **tableaux associatifs** (PHP). Très loin dans le temps, elles étaient connues comme **scatter tables** (tables de dispersion).

</aside>

^code environment-class

Il y a une Map Java là-dedans pour stocker les liaisons. Elle utilise des chaînes nues pour les clés, pas des tokens. Un token représente une unité de code à un endroit spécifique dans le texte source, mais quand il s'agit de chercher des variables, tous les tokens identifiants avec le même nom devraient se référer à la même variable (en ignorant la portée pour l'instant). Utiliser la chaîne brute assure que tous ces tokens se réfèrent à la même clé de map.

Il y a deux opérations que nous devons supporter. D'abord, une définition de variable lie un nouveau nom à une valeur.

^code environment-define

Pas exactement de la chirurgie du cerveau, mais nous avons fait un choix sémantique intéressant. Quand nous ajoutons la clé à la map, nous ne vérifions pas pour voir si elle est déjà présente. Cela signifie que ce programme fonctionne :

```lox
var a = "avant";
print a; // "avant".
var a = "après";
print a; // "après".
```

Une instruction de variable ne définit pas juste une _nouvelle_ variable, elle peut aussi être utilisée pour *re*définir une variable existante. Nous pourrions <span name="scheme">choisir</span> de faire de cela une erreur à la place. L'utilisateur peut ne pas avoir l'intention de redéfinir une variable existante. (S'ils le voulaient, ils auraient probablement utilisé l'affectation, pas `var`.) Faire de la redéfinition une erreur les aiderait à trouver ce bug.

Cependant, faire ainsi interagit mal avec le REPL. Au milieu d'une session REPL, c'est agréable de ne pas avoir à suivre mentalement quelles variables vous avez déjà définies. Nous pourrions autoriser la redéfinition dans le REPL mais pas dans les scripts, mais alors les utilisateurs devraient apprendre deux ensembles de règles, et le code copié et collé d'une forme à l'autre pourrait ne pas fonctionner.

<aside name="scheme">

Ma règle à propos des variables et de la portée est, "Dans le doute, fais ce que Scheme fait". Les gens de Scheme ont probablement passé plus de temps à penser à la portée des variables que nous ne le ferons jamais -- l'un des buts principaux de Scheme était d'introduire la portée lexicale au monde -- donc il est difficile de se tromper si vous suivez leurs traces.

Scheme autorise la redéfinition de variables au niveau supérieur.

</aside>

Donc, pour garder les deux modes cohérents, nous l'autoriserons -- au moins pour les variables globales. Une fois qu'une variable existe, nous avons besoin d'un moyen de la chercher.

^code environment-get (2 before, 1 after)

Ceci est un peu plus sémantiquement intéressant. Si la variable est trouvée, elle renvoie simplement la valeur liée à elle. Mais qu'en est-il si elle ne l'est pas ? Encore une fois, nous avons un choix :

- En faire une erreur de syntaxe.

- En faire une erreur d'exécution.

- L'autoriser et renvoyer une certaine valeur par défaut comme `nil`.

Lox est assez laxiste, mais la dernière option est un peu _trop_ permissive pour moi. En faire une erreur de syntaxe -- une erreur à la compilation -- semble être un choix intelligent. Utiliser une variable indéfinie est un bug, et plus tôt vous détectez l'erreur, mieux c'est.

Le problème est qu'_utiliser_ une variable n'est pas la même chose que s'y _référer_. Vous pouvez vous référer à une variable dans un morceau de code sans l'évaluer immédiatement si ce morceau de code est enveloppé à l'intérieur d'une fonction. Si nous en faisons une erreur statique de _mentionner_ une variable avant qu'elle ait été déclarée, cela devient beaucoup plus difficile de définir des fonctions récursives.

Nous pourrions accommoder la récursion simple -- une fonction qui s'appelle elle-même -- en déclarant le propre nom de la fonction avant que nous examinions son corps. Mais cela n'aide pas avec les procédures mutuellement récursives qui s'appellent l'une l'autre. Considérez :

<span name="contrived"></span>

```lox
fun isOdd(n) {
  if (n == 0) return false;
  return isEven(n - 1);
}

fun isEven(n) {
  if (n == 0) return true;
  return isOdd(n - 1);
}
```

<aside name="contrived">

Il est vrai que ce n'est probablement pas la façon la plus efficace de dire si un nombre est pair ou impair (sans mentionner les mauvaises choses qui arrivent si vous leur passez un non-entier ou un nombre négatif). Soyez indulgents avec moi.

</aside>

La fonction `isEven()` n'est pas définie au <span name="declare">moment</span> où nous regardons le corps de `isOdd()` où elle est appelée. Si nous échangeons l'ordre des deux fonctions, alors `isOdd()` n'est pas définie quand nous regardons le corps de `isEven()`.

<aside name="declare">

Certains langages typés statiquement comme Java et C# résolvent cela en spécifiant que le niveau supérieur d'un programme n'est pas une séquence d'instructions impératives. Au lieu de cela, un programme est un ensemble de déclarations qui viennent toutes à l'existence simultanément. L'implémentation déclare _tous_ les noms avant de regarder les corps de _n'importe quelle_ fonction.

Des langages plus vieux comme C et Pascal ne fonctionnent pas comme ça. Au lieu de cela, ils vous forcent à ajouter des _déclarations anticipées_ (forward declarations) explicites pour déclarer un nom avant qu'il soit entièrement défini. C'était une concession à la puissance de calcul limitée à l'époque. Ils voulaient être capables de compiler un fichier source en une seule passe à travers le texte, donc ces compilateurs ne pouvaient pas rassembler toutes les déclarations d'abord avant de traiter les corps de fonction.

</aside>

Puisque en faire une erreur _statique_ rend les déclarations récursives trop difficiles, nous différerons l'erreur à l'exécution. C'est OK de se référer à une variable avant qu'elle soit définie tant que vous n'_évaluez_ pas la référence. Cela laisse le programme pour les nombres pairs et impairs fonctionner, mais vous obtiendriez une erreur d'exécution dans :

```lox
print a;
var a = "trop tard !";
```

Comme avec les erreurs de type dans le code d'évaluation d'expression, nous rapportons une erreur d'exécution en lançant une exception. L'exception contient le token de la variable pour que nous puissions dire à l'utilisateur où dans son code il a fait une erreur.

### Interpréter les variables globales

La classe Interpreter obtient une instance de la nouvelle classe Environment.

^code environment-field (2 before, 1 after)

Nous la stockons comme un champ directement dans Interpreter pour que les variables restent en mémoire tant que l'interpréteur est encore en cours d'exécution.

Nous avons deux nouveaux arbres syntaxiques, donc c'est deux nouvelles méthodes visit. La première est pour les instructions de déclaration.

^code visit-var

Si la variable a un initialiseur, nous l'évaluons. Si non, nous avons un autre choix à faire. Nous aurions pu en faire une erreur de syntaxe dans le parseur en _exigeant_ un initialiseur. La plupart des langages ne le font pas, cependant, donc cela semble un peu dur de le faire dans Lox.

Nous pourrions en faire une erreur d'exécution. Nous vous laisserions définir une variable non initialisée, mais si vous y accédiez avant de lui assigner quelque chose, une erreur d'exécution se produirait. Ce n'est pas une mauvaise idée, mais la plupart des langages typés dynamiquement ne font pas ça. Au lieu de cela, nous garderons les choses simples et dirons que Lox définit une variable à `nil` si elle n'est pas explicitement initialisée.

```lox
var a;
print a; // "nil".
```

Ainsi, s'il n'y a pas d'initialiseur, nous définissons la valeur à `null`, qui est la représentation Java de la valeur `nil` de Lox. Puis nous disons à l'environnement de lier la variable à cette valeur.

Ensuite, nous évaluons une expression de variable.

^code visit-variable

Ceci transmet simplement à l'environnement qui fait le gros du travail pour s'assurer que la variable est définie. Avec cela, nous avons des variables rudimentaires qui fonctionnent. Essayez ceci :

```lox
var a = 1;
var b = 2;
print a + b;
```

Nous ne pouvons pas encore réutiliser de _code_, mais nous pouvons commencer à construire des programmes qui réutilisent des _données_.

## Affectation

Il est possible de créer un langage qui a des variables mais ne vous laisse pas les réassigner -- ou les **muter**. Haskell est un exemple. SML supporte seulement les références mutables et les tableaux -- les variables ne peuvent pas être réassignées. Rust vous éloigne de la mutation en exigeant un modificateur `mut` pour activer l'affectation.

Muter une variable est un effet de bord et, comme le nom le suggère, certains gens des langages pensent que les effets de bord sont <span name="pure">sales</span> ou inélégants. Le code devrait être des mathématiques pures qui produisent des valeurs -- cristallines, inchangeables -- comme un acte de création divine. Pas un automate crasseux qui bat des paquets de données pour leur donner forme, un grognement impératif à la fois.

<aside name="pure">

Je trouve délicieux que le même groupe de personnes qui sont fières de leur logique impartiale sont aussi celles qui ne peuvent pas résister aux termes chargés émotionnellement pour leur travail : "pur", "effet de bord", "paresseux", "persistant", "de première classe", "d'ordre supérieur".

</aside>

Lox n'est pas si austère. Lox est un langage impératif, et la mutation vient avec le territoire. Ajouter le support pour l'affectation (assignation) ne nécessite pas beaucoup de travail. Les variables globales supportent déjà la redéfinition, donc la plupart de la machinerie est là maintenant. Principalement, il nous manque une notation d'affectation explicite.

### Syntaxe d'affectation

Cette petite syntaxe `=` est plus complexe qu'elle pourrait le sembler. Comme la plupart des langages dérivés du C, l'affectation est une <span name="assign">expression</span> et non une instruction. Comme en C, c'est la forme d'expression de plus basse précédence. Cela signifie que la règle se glisse entre `expression` et `equality` (la prochaine expression de plus basse précédence).

<aside name="assign">

Dans certains autres langages, comme Pascal, Python, et Go, l'affectation est une instruction.

</aside>

```ebnf
expression     → assignment ;
assignment     → IDENTIFIER "=" assignment
               | equality ;
```

Ceci dit qu'une `assignment` (affectation) est soit un identifiant suivi par un `=` et une expression pour la valeur, ou une expression `equality` (et ainsi n'importe quelle autre). Plus tard, `assignment` deviendra plus complexe quand nous ajouterons les setters de propriété sur les objets, comme :

```lox
instance.field = "valeur";
```

La partie facile est d'ajouter le <span name="assign-ast">nouveau nœud d'arbre syntaxique</span>.

^code assign-expr (1 before, 1 after)

<aside name="assign-ast">

Le code généré pour le nouveau nœud est dans l'[Annexe II][appendix-assign].

[appendix-assign]: appendix-ii.html#assign-expression

</aside>

Il a un token pour la variable à laquelle on assigne, et une expression pour la nouvelle valeur. Après que vous exécutiez le générateur AST pour obtenir la nouvelle classe Expr.Assign, échangez le corps de la méthode `expression()` existante du parseur pour correspondre à la règle mise à jour.

^code expression (1 before, 1 after)

C'est ici que ça devient délicat. Un parseur à descente récursive avec un seul token de lookahead ne peut pas voir assez loin pour dire qu'il est en train de parser une affectation avant qu'il ait traversé le côté gauche et trébuché sur le `=`. Vous pourriez vous demander pourquoi il a même besoin de le savoir. Après tout, nous ne savons pas que nous parsons une expression `+` avant que nous ayons fini de parser l'opérande gauche.

La différence est que le côté gauche d'une affectation n'est pas une expression qui s'évalue en une valeur. C'est une sorte de pseudo-expression qui s'évalue en une "chose" à laquelle vous pouvez assigner. Considérez :

```lox
var a = "avant";
a = "valeur";
```

Sur la seconde ligne, nous n'_évaluons_ pas `a` (ce qui renverrait la chaîne "avant"). Nous comprenons à quelle variable `a` se réfère pour savoir où stocker la valeur de l'expression du côté droit. Les [termes classiques][l-value] pour ces deux <span name="l-value">constructions</span> sont **l-value** et **r-value**. Toutes les expressions que nous avons vues jusqu'ici qui produisent des valeurs sont des r-values. Une l-value "s'évalue" en un emplacement de stockage dans lequel vous pouvez assigner.

[l-value]: https://en.wikipedia.org/wiki/Value_(computer_science)#lrvalue

<aside name="l-value">

En fait, les noms viennent des expressions d'affectation : les _l_-values apparaissent sur le côté _gauche_ (left) du `=` dans une affectation, et les _r_-values sur la _droite_ (right).

</aside>

Nous voulons que l'arbre syntaxique reflète qu'une l-value n'est pas évaluée comme une expression normale. C'est pourquoi le nœud Expr.Assign a un _Token_ pour le côté gauche, pas une Expr. Le problème est que le parseur ne sait pas qu'il parse une l-value jusqu'à ce qu'il frappe le `=`. Dans une l-value complexe, cela peut se produire <span name="many">de nombreux</span> tokens plus tard.

```lox
makeList().head.next = node;
```

<aside name="many">

Puisque le receveur d'une affectation de champ peut être n'importe quelle expression, et que les expressions peuvent être aussi longues que vous voulez les faire, cela peut prendre un nombre _illimité_ de tokens de lookahead pour trouver le `=`.

</aside>

Nous avons seulement un token de lookahead, donc que faisons-nous ? Nous utilisons une petite astuce, et cela ressemble à ceci :

^code parse-assignment

La plupart du code pour parser une expression d'affectation ressemble à celui des autres opérateurs binaires comme `+`. Nous parsons le côté gauche, qui peut être n'importe quelle expression de plus haute précédence. Si nous trouvons un `=`, nous parsons le côté droit et ensuite enveloppons le tout dans un nœud d'arbre d'expression d'affectation.

<aside name="no-throw">

Nous _rapportons_ une erreur si le côté gauche n'est pas une cible d'affectation valide, mais nous ne la _lançons_ pas parce que le parseur n'est pas dans un état confus où nous avons besoin d'aller en mode panique et de synchroniser.

</aside>

Une légère différence avec les opérateurs binaires est que nous ne bouclons pas pour construire une séquence du même opérateur. Puisque l'affectation est associative à droite, nous appelons à la place récursivement `assignment()` pour parser le côté droit.

L'astuce est que juste avant que nous créions le nœud d'expression d'affectation, nous regardons l'expression du côté gauche et comprenons quel type de cible d'affectation c'est. Nous convertissons le nœud d'expression r-value en une représentation l-value.

Cette conversion fonctionne parce qu'il s'avère que chaque cible d'affectation valide se trouve être aussi une <span name="converse">syntaxe valide</span> comme expression normale. Considérez une affectation de champ complexe comme :

<aside name="converse">

Vous pouvez toujours utiliser cette astuce même s'il y a des cibles d'affectation qui ne sont pas des expressions valides. Définissez une **grammaire de couverture**, une grammaire plus lâche qui accepte toutes les syntaxes valides d'expression _et_ de cible d'affectation. Quand vous frappez un `=`, rapportez une erreur si le côté gauche n'est pas à l'intérieur de la grammaire de cible d'affectation valide. Inversement, si vous ne frappez _pas_ un `=`, rapportez une erreur si le côté gauche n'est pas une _expression_ valide.

</aside>

```lox
newPoint(x + 2, 0).y = 3;
```

Le côté gauche de cette affectation pourrait aussi fonctionner comme une expression valide.

```lox
newPoint(x + 2, 0).y;
```

Le premier exemple définit le champ, le second l'obtient.

Cela signifie que nous pouvons parser le côté gauche _comme si c'était_ une expression et ensuite après coup produire un arbre syntaxique qui le transforme en une cible d'affectation. Si l'expression du côté gauche n'est pas une cible d'affectation <span name="paren">valide</span>, nous échouons avec une erreur de syntaxe. Cela assure que nous rapportons une erreur sur du code comme ceci :

```lox
a + b = c;
```

<aside name="paren">

Loin en arrière dans le chapitre sur le parsing, j'ai dit que nous représentions les expressions parenthésées dans l'arbre syntaxique parce que nous en aurions besoin plus tard. C'est pourquoi. Nous devons être capables de distinguer ces cas :

```lox
a = 3;   // OK.
(a) = 3; // Erreur.
```

</aside>

Pour l'instant, la seule cible valide est une simple expression de variable, mais nous ajouterons les champs plus tard. Le résultat final de cette astuce est un nœud d'arbre d'expression d'affectation qui sait à quoi il assigne et a un sous-arbre d'expression pour la valeur étant assignée. Tout cela avec seulement un token de lookahead et pas de backtracking.

### Sémantique d'affectation

Nous avons un nouveau nœud d'arbre syntaxique, donc notre interpréteur obtient une nouvelle méthode visit.

^code visit-assign

Pour des raisons évidentes, c'est similaire à la déclaration de variable. Elle évalue le côté droit pour obtenir la valeur, puis la stocke dans la variable nommée. Au lieu d'utiliser `define()` sur Environment, elle appelle cette nouvelle méthode :

^code environment-assign

La différence clé entre l'affectation et la définition est que l'affectation n'est pas <span name="new">autorisée</span> à créer une _nouvelle_ variable. En termes de notre implémentation, cela signifie que c'est une erreur d'exécution si la clé n'existe pas déjà dans la map de variables de l'environnement.

<aside name="new">

Contrairement à Python et Ruby, Lox ne fait pas de [déclaration de variable implicite][implicit variable declaration].

[implicit variable declaration]: #design-note

</aside>

La dernière chose que la méthode `visit()` fait est de renvoyer la valeur assignée. C'est parce que l'affectation est une expression qui peut être imbriquée à l'intérieur d'autres expressions, comme ceci :

```lox
var a = 1;
print a = 2; // "2".
```

Notre interpréteur peut maintenant créer, lire, et modifier des variables. C'est à peu près aussi sophistiqué que les premiers <span name="basic">BASICs</span>. Les variables globales sont simples, mais écrire un gros programme quand deux morceaux de code quelconques peuvent accidentellement marcher sur l'état de l'autre n'est pas amusant. Nous voulons des variables _locales_, ce qui signifie qu'il est temps pour la _portée_.

<aside name="basic">

Peut-être un peu mieux que ça. Contrairement à certains vieux BASICs, Lox peut gérer des noms de variables plus longs que deux caractères.

</aside>

## Portée

Une **portée** (scope) définit une région où un nom mappe vers une certaine entité. De multiples portées permettent au même nom de se référer à différentes choses dans différents contextes. Dans ma maison, "Bob" se réfère généralement à moi. Mais peut-être que dans votre ville vous connaissez un Bob différent. Même nom, mais différents mecs basés sur où vous le dites.

La <span name="lexical">**portée lexicale**</span> (ou la **portée statique** moins communément entendue) est un style spécifique de portée où le texte du programme lui-même montre où une portée commence et se termine. Dans Lox, comme dans la plupart des langages modernes, les variables sont lexicalement portées. Quand vous voyez une expression qui utilise une certaine variable, vous pouvez comprendre à quelle déclaration de variable elle se réfère juste en lisant statiquement le code.

<aside name="lexical">

"Lexical" vient du grec "lexikos" qui signifie "lié aux mots". Quand nous l'utilisons dans les langages de programmation, cela signifie généralement une chose que vous pouvez comprendre à partir du code source lui-même sans avoir à exécuter quoi que ce soit.

La portée lexicale est arrivée sur la scène avec ALGOL. Les langages plus tôt étaient souvent portés dynamiquement. Les informaticiens à l'époque croyaient que la portée dynamique était plus rapide à exécuter. Aujourd'hui, grâce aux premiers hackers Scheme, nous savons que ce n'est pas vrai. Au contraire, c'est l'opposé.

La portée dynamique pour les variables survit dans certains coins. Emacs Lisp utilise par défaut la portée dynamique pour les variables. La macro [`binding`][binding] dans Clojure la fournit. L'instruction [`with`][with] largement détestée en JavaScript transforme les propriétés sur un objet en variables portées dynamiquement.

[binding]: http://clojuredocs.org/clojure.core/binding
[with]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/with

</aside>

Par exemple :

```lox
{
  var a = "premier";
  print a; // "premier".
}

{
  var a = "second";
  print a; // "second".
}
```

Ici, nous avons deux blocs avec une variable `a` déclarée dans chacun d'eux. Vous et moi pouvons dire juste en regardant le code que l'utilisation de `a` dans la première instruction `print` se réfère au premier `a`, et la seconde se réfère au second.

<img src="image/statements-and-state/blocks.png" alt="Un environnement pour chaque 'a'." />

Ceci est en contraste avec la **portée dynamique** où vous ne savez pas à quoi un nom se réfère avant d'exécuter le code. Lox n'a pas de _variables_ portées dynamiquement, mais les méthodes et champs sur les objets sont portés dynamiquement.

```lox
class Saxophone {
  play() {
    print "Careless Whisper";
  }
}

class GolfClub {
  play() {
    print "Fore!";
  }
}

fun playIt(thing) {
  thing.play();
}
```

Quand `playIt()` appelle `thing.play()`, nous ne savons pas si nous sommes sur le point d'entendre "Careless Whisper" ou "Fore!". Cela dépend de si vous passez un Saxophone ou un GolfClub à la fonction, et nous ne le savons pas avant l'exécution.

La portée et les environnements sont des cousins proches. La première est le concept théorique, et le second est la machinerie qui l'implémente. Alors que notre interpréteur fait son chemin à travers le code, les nœuds d'arbre syntaxique qui affectent la portée changeront l'environnement. Dans une syntaxe à la C comme celle de Lox, la portée est contrôlée par des blocs entre accolades. (C'est pourquoi nous l'appelons **portée de bloc**.)

```lox
{
  var a = "dans le bloc";
}
print a; // Erreur ! Plus de "a".
```

Le début d'un bloc introduit une nouvelle portée locale, et cette portée se termine quand l'exécution passe le `}` fermant. Toutes les variables déclarées à l'intérieur du bloc disparaissent.

### Imbrication et masquage

Un premier essai pour implémenter la portée de bloc pourrait fonctionner comme ceci :

1.  Alors que nous visitons chaque instruction à l'intérieur du bloc, garder une trace de toutes les variables déclarées.

2.  Après que la dernière instruction est exécutée, dire à l'environnement de supprimer toutes ces variables.

Cela fonctionnerait pour l'exemple précédent. Mais rappelez-vous, une motivation pour la portée locale est l'encapsulation -- un bloc de code dans un coin du programme ne devrait pas interférer avec un autre bloc. Regardez ça :

```lox
// Quel volume ?
var volume = 11;

// Silence.
volume = 0;

// Calculer la taille d'un cuboïde 3x4x5.
{
  var volume = 3 * 4 * 5;
  print volume;
}
```

Regardez le bloc où nous calculons le volume du cuboïde en utilisant une déclaration locale de `volume`. Après que le bloc sorte, l'interpréteur supprimera la variable `volume` _globale_. Ce n'est pas juste. Quand nous sortons du bloc, nous devrions retirer toutes les variables déclarées à l'intérieur du bloc, mais s'il y a une variable avec le même nom déclarée à l'extérieur du bloc, _c'est une variable différente_. Elle ne devrait pas être touchée.

Quand une variable locale a le même nom qu'une variable dans une portée englobante, elle **masque** (shadows) l'externe. Le code à l'intérieur du bloc ne peut plus la voir -- elle est cachée dans l'"ombre" jetée par l'interne -- mais elle est toujours là.

Quand nous entrons dans une nouvelle portée de bloc, nous devons préserver les variables définies dans les portées externes pour qu'elles soient toujours là quand nous sortons du bloc interne. Nous faisons cela en définissant un environnement frais pour chaque bloc contenant seulement les variables définies dans cette portée. Quand nous sortons du bloc, nous rejetons son environnement et restaurons le précédent.

Nous avons aussi besoin de gérer les variables englobantes qui ne sont _pas_ masquées.

```lox
var global = "dehors";
{
  var local = "dedans";
  print global + local;
}
```

Ici, `global` vit dans l'environnement global externe et `local` est défini à l'intérieur de l'environnement du bloc. Dans cette instruction `print`, ces deux variables sont dans la portée. Afin de les trouver, l'interpréteur doit chercher non seulement l'environnement le plus interne courant, mais aussi tous ceux englobants.

Nous implémentons cela en <span name="cactus">chaînant</span> les environnements ensemble. Chaque environnement a une référence vers l'environnement de la portée immédiatement englobante. Quand nous cherchons une variable, nous marchons dans cette chaîne du plus interne vers l'extérieur jusqu'à ce que nous trouvions la variable. Commencer à la portée interne est la façon dont nous faisons masquer les variables externes par les locales.

<img src="image/statements-and-state/chaining.png" alt="Environnements pour chaque portée, liés ensemble." />

<aside name="cactus">

Pendant que l'interpréteur tourne, les environnements forment une liste linéaire d'objets, mais considérez l'ensemble complet des environnements créés durant l'exécution entière. Une portée externe peut avoir de multiples blocs imbriqués en son sein, et chacun pointera vers l'externe, donnant une structure arborescente, bien qu'un seul chemin à travers l'arbre existe à la fois.

Le nom ennuyeux pour cela est un [**arbre à pointeur de parent**][parent pointer], mais je préfère de loin le nom évocateur de **pile cactus**.

[parent pointer]: https://en.wikipedia.org/wiki/Parent_pointer_tree

<img class="above" src="image/statements-and-state/cactus.png" alt="Chaque branche pointe vers son parent. La racine est la portée globale." />

</aside>

Avant que nous ajoutions la syntaxe de bloc à la grammaire, nous allons renforcer notre classe Environment avec le support pour cette imbrication. D'abord, nous donnons à chaque environnement une référence vers son englobant.

^code enclosing-field (1 before, 1 after)

Ce champ doit être initialisé, donc nous ajoutons une paire de constructeurs.

^code environment-constructors

Le constructeur sans argument est pour l'environnement de la portée globale, qui termine la chaîne. L'autre constructeur crée une nouvelle portée locale imbriquée à l'intérieur de celle externe donnée.

Nous n'avons pas à toucher la méthode `define()` -- une nouvelle variable est toujours déclarée dans la portée la plus interne courante. Mais la recherche de variable et l'affectation fonctionnent avec des variables existantes et elles doivent marcher dans la chaîne pour les trouver. D'abord, la recherche :

^code environment-get-enclosing (2 before, 3 after)

Si la variable n'est pas trouvée dans cet environnement, nous essayons simplement celui englobant. Celui-là fait à son tour la même chose <span name="recurse">récursivement</span>, donc cela marchera finalement la chaîne entière. Si nous atteignons un environnement sans englobant et ne trouvons toujours pas la variable, alors nous abandonnons et rapportons une erreur comme avant.

L'affectation fonctionne de la même manière.

<aside name="recurse">

C'est probablement plus rapide de marcher itérativement dans la chaîne, mais je pense que la solution récursive est plus jolie. Nous ferons quelque chose de _beaucoup_ plus rapide dans clox.

</aside>

^code environment-assign-enclosing (4 before, 1 after)

Encore une fois, si la variable n'est pas dans cet environnement, elle vérifie l'externe, récursivement.

### Syntaxe et sémantique de bloc

Maintenant que les environnements s'imbriquent, nous sommes prêts à ajouter les blocs au langage. Contemplez la grammaire :

```ebnf
statement      → exprStmt
               | printStmt
               | block ;

block          → "{" declaration* "}" ;
```

Un bloc est une série (possiblement vide) d'instructions ou de déclarations entourée par des accolades. Un bloc est lui-même une instruction et peut apparaître n'importe où une instruction est autorisée. Le nœud d'<span name="block-ast">arbre syntaxique</span> ressemble à ceci :

^code block-ast (1 before, 1 after)

<aside name="block-ast">

Le code généré pour le nouveau nœud est dans l'[Annexe II][appendix-block].

[appendix-block]: appendix-ii.html#block-statement

</aside>

<span name="generate">Il</span> contient la liste des instructions qui sont à l'intérieur du bloc. Le parsing est direct. Comme d'autres instructions, nous détectons le début d'un bloc par son token de tête -- dans ce cas le `{`. Dans la méthode `statement()`, nous ajoutons :

<aside name="generate">

Comme toujours, n'oubliez pas d'exécuter "GenerateAst.java".

</aside>

^code parse-block (1 before, 2 after)

Tout le vrai travail se passe ici :

^code block

Nous <span name="list">créons</span> une liste vide et ensuite parsons les instructions et les ajoutons à la liste jusqu'à ce que nous atteignions la fin du bloc, marquée par le `}` fermant. Notez que la boucle a aussi une vérification explicite pour `isAtEnd()`. Nous devons faire attention à éviter les boucles infinies, même en parsant du code invalide. Si l'utilisateur oublie un `}` fermant, le parseur ne doit pas rester coincé.

<aside name="list">

Faire que `block()` renvoie la liste brute d'instructions et laisser à `statement()` le soin d'envelopper la liste dans un Stmt.Block semble un peu bizarre. Je l'ai fait de cette façon parce que nous réutiliserons `block()` plus tard pour parser les corps de fonction et nous ne voulons pas que ce corps soit enveloppé dans un Stmt.Block.

</aside>

C'est tout pour la syntaxe. Pour la sémantique, nous ajoutons une autre méthode visit à Interpreter.

^code visit-block

Pour exécuter un bloc, nous créons un nouvel environnement pour la portée du bloc et le passons à cette autre méthode :

^code execute-block

Cette nouvelle méthode exécute une liste d'instructions dans le contexte d'un <span name="param">environnement</span> donné. Jusqu'à maintenant, le champ `environment` dans Interpreter pointait toujours vers le même environnement -- le global. Maintenant, ce champ représente l'environnement _courant_. C'est l'environnement qui correspond à la portée la plus interne contenant le code à exécuter.

Pour exécuter du code au sein d'une portée donnée, cette méthode met à jour le champ `environment` de l'interpréteur, visite toutes les instructions, et ensuite restaure la valeur précédente. Comme c'est toujours une bonne pratique en Java, elle restaure l'environnement précédent en utilisant une clause finally. De cette façon il est restauré même si une exception est lancée.

<aside name="param">

Changer manuellement et restaurer un champ `environment` mutable semble inélégant. Une autre approche classique est de passer explicitement l'environnement comme paramètre à chaque méthode visit. Pour "changer" l'environnement, vous en passez un différent alors que vous récursez vers le bas de l'arbre. Vous n'avez pas à restaurer l'ancien, puisque le nouveau vit sur la pile Java et est implicitement rejeté quand l'interpréteur revient de la méthode visit du bloc.

J'ai considéré cela pour jlox, mais c'est un peu fastidieux et verbeux d'ajouter un paramètre environnement à chaque méthode visit unique. Pour garder le livre un peu plus simple, je suis allé avec le champ mutable.

</aside>

Étonnamment, c'est tout ce que nous avons besoin de faire afin de supporter entièrement les variables locales, l'imbrication, et le masquage. Allez-y et essayez ceci :

```lox
var a = "global a";
var b = "global b";
var c = "global c";
{
  var a = "outer a";
  var b = "outer b";
  {
    var a = "inner a";
    print a;
    print b;
    print c;
  }
  print a;
  print b;
  print c;
}
print a;
print b;
print c;
```

Notre petit interpréteur peut se souvenir de choses maintenant. Nous nous rapprochons centimètre par centimètre de quelque chose ressemblant à un langage de programmation complet.

<div class="challenges">

## Défis

1.  Le REPL ne supporte plus l'entrée d'une seule expression et l'impression automatique de sa valeur résultat. C'est barbant. Ajoutez le support au REPL pour laisser les utilisateurs taper à la fois des instructions et des expressions. S'ils entrent une instruction, exécutez-la. S'ils entrent une expression, évaluez-la et affichez la valeur résultat.

2.  Peut-être voulez-vous que Lox soit un peu plus explicite à propos de l'initialisation de variable. Au lieu d'initialiser implicitement les variables à `nil`, faites-en une erreur d'exécution d'accéder à une variable qui n'a pas été initialisée ou assignée, comme dans :

    ```lox
    // Pas d'initialiseurs.
    var a;
    var b;

    a = "assigné";
    print a; // OK, a été assigné en premier.

    print b; // Erreur !
    ```

3.  Que fait le programme suivant ?

    ```lox
    var a = 1;
    {
      var a = a + 2;
      print a;
    }
    ```

    que vous _attendiez_-vous à ce qu'il fasse ? Est-ce ce que vous pensez qu'il devrait faire ? Que fait le code analogue dans d'autres langages avec lesquels vous êtes familiers ? Que pensez-vous que les utilisateurs s'attendront à ce qu'il fasse ?

</div>

<div class="design-note">

## Note de Conception : Déclaration de Variable Implicite

Lox a une syntaxe distincte pour déclarer une nouvelle variable et assigner à une existante. Certains langages effondrent celles-ci en seulement la syntaxe d'affectation. Assigner à une variable non-existante l'amène automatiquement à l'existence. Ceci est appelé **déclaration de variable implicite** et existe en Python, Ruby, et CoffeeScript, parmi d'autres. JavaScript a une syntaxe explicite pour déclarer des variables, mais peut aussi créer de nouvelles variables lors de l'affectation. Visual Basic a [une option pour activer ou désactiver les variables implicites][vb].

[vb]: https://msdn.microsoft.com/en-us/library/xe53dz5w(v=vs.100).aspx

Quand la même syntaxe peut assigner ou créer une variable, chaque langage doit décider ce qui se passe quand il n'est pas clair quel comportement l'utilisateur a l'intention d'avoir. En particulier, chaque langage doit choisir comment la déclaration implicite interagit avec le masquage, et dans quelle portée une variable implicitement déclarée va.

- En Python, l'affectation crée toujours une variable dans la portée de la fonction courante, même s'il y a une variable avec le même nom déclarée à l'extérieur de la fonction.

- Ruby évite une certaine ambiguïté en ayant des règles de nommage différentes pour les variables locales et globales. Cependant, les blocs en Ruby (qui sont plus comme des fermetures que comme des "blocs" en C) ont leur propre portée, donc il a toujours le problème. L'affectation en Ruby assigne à une variable existante à l'extérieur du bloc courant s'il y en a une avec le même nom. Sinon, elle crée une nouvelle variable dans la portée du bloc courant.

- CoffeeScript, qui tient de Ruby de nombreuses façons, est similaire. Il interdit explicitement le masquage en disant que l'affectation assigne toujours à une variable dans une portée externe s'il y en a une, tout le chemin jusqu'à la portée globale la plus externe. Sinon, il crée la variable dans la portée de la fonction courante.

- En JavaScript, l'affectation modifie une variable existante dans n'importe quelle portée englobante, si trouvée. Si non, elle crée implicitement une nouvelle variable dans la portée _globale_.

L'avantage principal de la déclaration implicite est la simplicité. Il y a moins de syntaxe et pas de concept de "déclaration" à apprendre. Les utilisateurs peuvent juste commencer à assigner des trucs et le langage se débrouille.

Les langages plus vieux, typés statiquement comme C bénéficient de la déclaration explicite parce qu'ils donnent à l'utilisateur un endroit pour dire au compilateur quel type chaque variable a et combien de stockage allouer pour elle. Dans un langage typé dynamiquement, ramassé par le garbage collector, ce n'est pas vraiment nécessaire, donc vous pouvez vous en sortir en rendant les déclarations implicites. Cela semble un peu plus "scripty", plus "tu vois ce que je veux dire".

Mais est-ce une bonne idée ? La déclaration implicite a quelques problèmes.

- Un utilisateur peut avoir l'intention d'assigner à une variable existante, mais peut l'avoir mal orthographiée. L'interpréteur ne le sait pas, donc il y va et crée silencieusement une nouvelle variable et la variable à laquelle l'utilisateur voulait assigner a toujours son ancienne valeur. C'est particulièrement odieux en JavaScript où une faute de frappe créera une variable _globale_, qui peut à son tour interférer avec d'autre code.

- JS, Ruby, et CoffeeScript utilisent la présence d'une variable existante avec le même nom -- même dans une portée externe -- pour déterminer si oui ou non une affectation crée une nouvelle variable ou assigne à une existante. Cela signifie qu'ajouter une nouvelle variable dans une portée environnante peut changer le sens du code existant. Ce qui était une fois une variable locale peut silencieusement se transformer en une affectation à cette nouvelle variable externe.

- En Python, vous pouvez _vouloir_ assigner à une variable à l'extérieur de la fonction courante au lieu de créer une nouvelle variable dans la courante, mais vous ne pouvez pas.

Avec le temps, les langages que je connais avec déclaration de variable implicite ont fini par ajouter plus de fonctionnalités et de complexité pour gérer ces problèmes.

- La déclaration implicite de variables globales en JavaScript est universellement considérée comme une erreur aujourd'hui. Le "mode strict" la désactive et en fait une erreur de compilation.

- Python a ajouté une instruction `global` pour vous laisser assigner explicitement à une variable globale depuis l'intérieur d'une fonction. Plus tard, alors que la programmation fonctionnelle et les fonctions imbriquées devenaient plus populaires, ils ont ajouté une instruction `nonlocal` similaire pour assigner aux variables dans les fonctions englobantes.

- Ruby a étendu sa syntaxe de bloc pour permettre de déclarer certaines variables comme étant explicitement locales au bloc même si le même nom existe dans une portée externe.

Étant donné ceux-là, je pense que l'argument de simplicité est principalement perdu. Il y a un argument que la déclaration implicite est le bon _défaut_ mais je trouve personnellement cela moins convaincant.

Mon opinion est que la déclaration implicite avait du sens dans les années passées quand la plupart des langages de script étaient lourdement impératifs et le code était assez plat. À mesure que les programmeurs sont devenus plus à l'aise avec l'imbrication profonde, la programmation fonctionnelle, et les fermetures, il est devenu beaucoup plus courant de vouloir accéder aux variables dans les portées externes. Cela rend plus probable le fait que les utilisateurs tomberont dans les cas délicats où il n'est pas clair s'ils ont l'intention que leur affectation crée une nouvelle variable ou réutilise une environnante.

Donc je préfère déclarer explicitement les variables, c'est pourquoi Lox l'exige.

</div>
