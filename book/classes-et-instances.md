> S'inquiéter trop pour les objets peut vous détruire. Seulement -- si vous tenez assez à une chose, elle prend une vie propre, n'est-ce pas ? Et n'est-ce pas tout le point des choses -- des belles choses -- qu'elles vous connectent à une plus grande beauté ?
>
> <cite>Donna Tartt, <em>Le Chardonneret</em></cite>

La dernière zone laissée à implémenter dans clox est la programmation orientée objet. La <span name="oop">POO</span> est un paquet de fonctionnalités entrelacées : classes, instances, champs, méthodes, initialisateurs, et héritage. Utilisant du Java de relativement haut niveau, nous avons emballé tout cela dans deux chapitres. Maintenant que nous codons en C, qui ressemble à construire une maquette de la tour Eiffel avec des cure-dents, nous dévouerons trois chapitres à couvrir le même territoire. Cela fait une promenade tranquille à travers l'implémentation. Après des chapitres ardus comme [les fermetures][closures] et le [ramasse-miettes][garbage collector], vous avez mérité un repos. En fait, le livre devrait être facile à partir de maintenant.

<aside name="oop">

Les gens qui ont des opinions fortes sur la programmation orientée objet -- lisez "tout le monde" -- tendent à supposer que la POO signifie une liste très spécifique de fonctionnalités de langage, mais vraiment il y a tout un espace à explorer, et chaque langage a ses propres ingrédients et recettes.

Self a des objets mais pas de classes. CLOS a des méthodes mais ne les attache à aucune classe spécifique. C++ initialement n'avait pas de polymorphisme d'exécution -- pas de méthodes virtuelles. Python a l'héritage multiple, mais Java ne l'a pas. Ruby attache les méthodes aux classes, mais vous pouvez aussi définir des méthodes sur un seul objet.

</aside>

Dans ce chapitre, nous couvrons les trois premières fonctionnalités : classes, instances, et champs. C'est le côté avec état de l'orientation objet. Ensuite dans les deux prochains chapitres, nous accrocherons le comportement et la réutilisation de code à ces objets.

[closures]: fermetures.html
[garbage collector]: ramasse-miettes.html

## Objets Classe

Dans un langage orienté objet basé sur les classes, tout commence avec les classes. Elles définissent quelles sortes d'objets existent dans le programme et sont les usines utilisées pour produire de nouvelles instances. Allant de bas en haut, nous commencerons avec leur représentation à l'exécution et ensuite accrocherons cela dans le langage.

À ce point, nous sommes bien accoutumés avec le processus d'ajouter un nouveau type d'objet à la VM. Nous commençons avec une struct.

^code obj-class (1 before, 2 after)

Après l'en-tête Obj, nous stockons le nom de la classe. Ce n'est pas strictement nécessaire pour le programme de l'utilisateur, mais cela nous laisse montrer le nom à l'exécution pour des choses comme les traces de pile.

Le nouveau type nécessite un cas correspondant dans l'énumération ObjType.

^code obj-type-class (1 before, 1 after)

Et ce type obtient une paire de macros correspondante. D'abord, pour tester le type d'un objet :

^code is-class (2 before, 1 after)

Et ensuite pour caster une Value en un pointeur ObjClass :

^code as-class (2 before, 1 after)

La VM crée de nouveaux objets classe utilisant cette fonction :

^code new-class-h (2 before, 1 after)

L'implémentation vit par ici :

^code new-class

Quasiment tout du code standard. Elle prend le nom de la classe comme une chaîne et le stocke. Chaque fois que l'utilisateur déclare une nouvelle classe, la VM créera une nouvelle de ces structs ObjClass pour la représenter.

<aside name="klass">

<img src="image/classes-and-instances/klass.png" alt="'Klass' dans une police farfelue pour enfants."/>

J'ai nommé la variable "klass" pas juste pour donner à la VM une sensation farfelue de maternelle "Coin des Enfants". Cela rend plus facile de faire compiler clox comme du C++ où "class" est un mot réservé.

</aside>

Quand la VM n'a plus besoin d'une classe, elle la libère comme ceci :

^code free-class (1 before, 1 after)

<aside name="braces">

Les accolades ici sont inutiles maintenant, mais seront utiles dans le prochain chapitre quand nous ajouterons un peu plus de code au case du switch.

</aside>

Nous avons un gestionnaire de mémoire maintenant, donc nous devons aussi supporter le traçage à travers les objets classe.

^code blacken-class (1 before, 1 after)

Quand le GC atteint un objet classe, il marque le nom de la classe pour garder cette chaîne vivante aussi.

La dernière opération que la VM peut effectuer sur une classe est de l'afficher.

^code print-class (1 before, 1 after)

Une classe dit simplement son propre nom.

## Déclarations de Classe

Représentation runtime en main, nous sommes prêts à ajouter le support pour les classes au langage. Ensuite, nous bougeons dans l'analyseur.

^code match-class (1 before, 1 after)

Les déclarations de classe sont des instructions, et l'analyseur en reconnaît une par le mot-clé `class` en tête. Le reste de la compilation se passe par ici :

^code class-declaration

Immédiatement après le mot-clé `class` est le nom de la classe. Nous prenons cet identifiant et l'ajoutons à la table de constantes de la fonction environnante comme une chaîne. Comme vous venez de le voir, afficher une classe montre son nom, donc le compilateur a besoin de fourrer la chaîne du nom quelque part que le runtime peut trouver. La table de constantes est la façon de faire cela.

Le <span name="variable">nom</span> de la classe est aussi utilisé pour lier l'objet classe à une variable du même nom. Donc nous déclarons une variable avec cet identifiant juste après avoir consommé son jeton.

<aside name="variable">

Nous aurions pu faire que les déclarations de classe soient des _expressions_ au lieu d'instructions -- elles sont essentiellement un littéral qui produit une valeur après tout. Alors les utilisateurs auraient à lier explicitement la classe à une variable eux-mêmes comme :

```lox
var Pie = class {}
```

Sorte de comme les fonctions lambda mais pour les classes. Mais puisque nous voulons généralement que les classes soient nommées de toute façon, cela a du sens de les traiter comme des déclarations.

</aside>

Ensuite, nous émettons une nouvelle instruction pour créer réellement l'objet classe à l'exécution. Cette instruction prend l'index de table de constantes du nom de la classe comme un opérande.

Après cela, mais avant de compiler le corps de la classe, nous définissons la variable pour le nom de la classe. _Déclarer_ la variable l'ajoute à la portée, mais rappelez-vous d'[un chapitre précédent][scope] que nous ne pouvons pas _utiliser_ la variable jusqu'à ce qu'elle soit _définie_. Pour les classes, nous définissons la variable avant le corps. De cette façon, les utilisateurs peuvent se référer à la classe contenante à l'intérieur des corps de ses propres méthodes. C'est utile pour des choses comme les méthodes usines qui produisent de nouvelles instances de la classe.

[scope]: variables-locales.html#un-autre-cas-limite-de-portée

Finalement, nous compilons le corps. Nous n'avons pas de méthodes encore, donc juste maintenant c'est simplement une paire d'accolades vide. Lox ne requiert pas que les champs soient déclarés dans la classe, donc nous en avons fini avec le corps -- et l'analyseur -- pour l'instant.

Le compilateur émet une nouvelle instruction, donc définissons cela.

^code class-op (1 before, 1 after)

Et ajoutons-la au désassembleur :

^code disassemble-class (2 before, 1 after)

Pour une fonctionnalité d'apparence si large, le support de l'interpréteur est minimal.

^code interpret-class (2 before, 1 after)

Nous chargeons la chaîne pour le nom de la classe depuis la table de constantes et passons cela à `newClass()`. Cela crée un nouvel objet classe avec le nom donné. Nous empilons cela sur la pile et nous sommes bons. Si la classe est liée à une variable globale, alors l'appel du compilateur à `defineVariable()` émettra du code pour stocker cet objet de la pile dans la table des variables globales. Sinon, c'est juste où cela doit être sur la pile pour une nouvelle variable <span name="local">locale</span>.

<aside name="local">

Les classes "locales" -- classes déclarées à l'intérieur du corps d'une fonction ou d'un bloc, sont un concept inhabituel. Beaucoup de langages ne les permettent pas du tout. Mais puisque Lox est un langage de script typé dynamiquement, il traite le niveau supérieur d'un programme et les corps des fonctions et des blocs uniformément. Les classes sont juste une autre sorte de déclaration, et puisque vous pouvez déclarer des variables et des fonctions à l'intérieur des blocs, vous pouvez déclarer des classes là-dedans aussi.

</aside>

Là vous l'avez, notre VM supporte les classes maintenant. Vous pouvez exécuter ceci :

```lox
class Brioche {}
print Brioche;
```

Malheureusement, afficher est à propos de _tout_ ce que vous pouvez faire avec les classes, donc la suite est de les rendre plus utiles.

## Instances de Classes

Les classes servent deux buts principaux dans un langage :

- **Elles sont comment vous créez de nouvelles instances.** Parfois cela implique un mot-clé `new`, d'autres fois c'est un appel de méthode sur l'objet classe, mais vous mentionnez habituellement la classe par nom _d'une façon ou d'une autre_ pour obtenir une nouvelle instance.

- **Elles contiennent des méthodes.** Celles-ci définissent comment toutes les instances de la classe se comportent.

Nous n'arriverons pas aux méthodes avant le prochain chapitre, donc pour l'instant nous nous inquiéterons seulement de la première partie. Avant que les classes puissent créer des instances, nous avons besoin d'une représentation pour elles.

^code obj-instance (1 before, 2 after)

Les instances connaissent leur classe -- chaque instance a un pointeur vers la classe dont elle est une instance. Nous n'utiliserons pas beaucoup cela dans ce chapitre, mais cela deviendra critique quand nous ajouterons les méthodes.

Plus important à ce chapitre est comment les instances stockent leur état. Lox laisse les utilisateurs ajouter librement des champs à une instance à l'exécution. Cela signifie que nous avons besoin d'un mécanisme de stockage qui peut grandir. Nous pourrions utiliser un tableau dynamique, mais nous voulons aussi chercher les champs par nom aussi vite que possible. Il y a une structure de données qui est juste parfaite pour accéder rapidement à un ensemble de valeurs par nom et -- encore plus commodément -- nous l'avons déjà implémentée. Chaque instance stocke ses champs utilisant une table de hachage.

<aside name="fields">

Être capable d'ajouter librement des champs à un objet à l'exécution est une grosse différence pratique entre la plupart des langages dynamiques et statiques. Les langages typés statiquement requièrent souvent que les champs soient explicitement déclarés. De cette façon, le compilateur sait exactement quels champs chaque instance a. Il peut utiliser cela pour déterminer la quantité précise de mémoire nécessaire pour chaque instance et les décalages dans cette mémoire où chaque champ peut être trouvé.

Dans Lox et d'autres langages dynamiques, accéder à un champ est habituellement une recherche dans une table de hachage. Temps constant, mais toujours assez lourd. Dans un langage comme C++, accéder à un champ est aussi rapide que décaler un pointeur par une constante entière.

</aside>

Nous avons seulement besoin d'ajouter une inclusion, et nous l'avons.

^code object-include-table (1 before, 1 after)

Cette nouvelle struct obtient un nouveau type d'objet.

^code obj-type-instance (1 before, 1 after)

Je veux ralentir un peu ici parce que la notion de "type" du _langage_ Lox et la notion de "type" de l'_implémentation_ de la VM se frottent l'une contre l'autre de façons qui peuvent être déroutantes. À l'intérieur du code C qui fait clox, il y a un nombre de différents types d'Obj -- ObjString, ObjClosure, etc. Chacun a sa propre représentation interne et sémantique.

Dans le _langage_ Lox, les utilisateurs peuvent définir leurs propres classes -- disons Gateau et Tarte -- et ensuite créer des instances de ces classes. De la perspective de l'utilisateur, une instance de Gateau est un type d'objet différent qu'une instance de Tarte. Mais, de la perspective de la VM, chaque classe que l'utilisateur définit est simplement une autre valeur de type ObjClass. De même, chaque instance dans le programme de l'utilisateur, peu importe de quelle classe elle est une instance, est une ObjInstance. Ce seul type d'objet VM couvre les instances de toutes les classes. Les deux mondes mappent l'un à l'autre quelque chose comme ceci :

<img src="image/classes-and-instances/lox-clox.png" alt="Un ensemble de déclarations de classe et d'instances, et les représentations runtime auxquelles chacune mappe."/>

Compris ? OK, retour à l'implémentation. Nous obtenons aussi nos macros habituelles.

^code is-instance (1 before, 1 after)

Et :

^code as-instance (1 before, 1 after)

Puisque les champs sont ajoutés après que l'instance est créée, la fonction "constructeur" a seulement besoin de connaître la classe.

^code new-instance-h (1 before, 1 after)

Nous implémentons cette fonction ici :

^code new-instance

Nous stockons une référence vers la classe de l'instance. Ensuite nous initialisons la table des champs à une table de hachage vide. Un nouveau bébé objet est né !
À la fin plus triste de la durée de vie de l'instance, elle est libérée.

^code free-instance (3 before, 1 after)

L'instance possède sa table de champs donc lors de la libération de l'instance, nous libérons aussi la table. Nous ne libérons pas explicitement les entrées _dans_ la table, parce qu'il peut y avoir d'autres références à ces objets. Le ramasse-miettes prendra soin de ceux-là pour nous. Ici nous libérons seulement le tableau d'entrée de la table elle-même.

Parlant du ramasse-miettes, il a besoin de support pour tracer à travers les instances.

^code blacken-instance (3 before, 1 after)

Si l'instance est vivante, nous avons besoin de garder sa classe autour. Aussi, nous avons besoin de garder chaque objet référencé par les champs de l'instance. La plupart des objets vivants qui ne sont pas des racines sont atteignables parce que quelque instance se réfère à l'objet dans un champ. Heureusement, nous avons déjà une belle fonction `markTable()` pour rendre leur traçage facile.

Moins critique mais toujours important est l'affichage.

^code print-instance (1 before, 1 after)

<span name="print">Une</span> instance affiche son nom suivi par "instance". (La partie "instance" est principalement pour que les classes et les instances n'affichent pas la même chose.)

<aside name="print">

La plupart des langages orientés objet laissent une classe définir quelque sorte de méthode `toString()` qui laisse la classe spécifier comment ses instances sont converties en une chaîne et affichées. Si Lox était moins un langage jouet, je voudrais supporter cela aussi.

</aside>

Le vrai amusement se passe là-bas dans l'interpréteur. Lox n'a pas de mot-clé spécial `new`. La façon de créer une instance d'une classe est d'invoquer la classe elle-même comme si c'était une fonction. Le runtime supporte déjà les appels de fonction, et il vérifie le type de l'objet étant appelé pour s'assurer que l'utilisateur n'essaie pas d'invoquer un nombre ou un autre type invalide.

Nous étendons cette vérification runtime avec un nouveau cas.

^code call-class (1 before, 1 after)

Si la valeur étant appelée -- l'objet qui résulte lors de l'évaluation de l'expression à la gauche de la parenthèse ouvrante -- est une classe, alors nous la traitons comme un appel de constructeur. Nous <span name="args">créons</span> une nouvelle instance de la classe appelée et stockons le résultat sur la pile.

<aside name="args">

Nous ignorons tous arguments passés à l'appel pour l'instant. Nous revisiterons ce code dans le [prochain chapitre][next] quand nous ajouterons le support pour les initialisateurs.

[next]: méthodes-et-initialisateurs.html

</aside>

Nous sommes une étape plus loin. Maintenant nous pouvons définir des classes et créer des instances d'elles.

```lox
class Brioche {}
print Brioche();
```

Notez les parenthèses après `Brioche` sur la seconde ligne maintenant. Ceci affiche "Brioche instance".

## Expressions Get et Set

Notre représentation objet pour les instances peut déjà stocker l'état, donc tout ce qui reste est d'exposer cette fonctionnalité à l'utilisateur. Les champs sont accédés et modifiés utilisant des expressions get et set. Pas un pour rompre avec la tradition, Lox utilise la syntaxe "point" classique :

```lox
eclair.filling = "pastry creme";
print eclair.filling;
```

Le point fonctionne <span name="sort">sorte</span> de comme un opérateur infixe. Il y a une expression à la gauche qui est évaluée d'abord et produit une instance. Après cela est le `.` suivi par un nom de champ. Puisqu'il y a un opérande précédent, nous accrochons ceci dans la table d'analyse comme une expression infixe.

<aside name="sort">

Je dis "sorte de" parce que le côté droit après le `.` n'est pas une expression, mais un seul identifiant dont la sémantique est gérée par l'expression get ou set elle-même. C'est vraiment plus proche d'une expression postfixe.

</aside>

^code table-dot (1 before, 1 after)

Comme dans d'autres langages, l'opérateur `.` lie fortement, avec une précédence aussi haute que les parenthèses dans un appel de fonction. Après que l'analyseur consomme le jeton point, il dépêche vers une nouvelle fonction d'analyse.

^code compile-dot

L'analyseur s'attend à trouver un nom de <span name="prop">propriété</span> immédiatement après le point. Nous chargeons le lexème de ce jeton dans la table de constantes comme une chaîne pour que le nom soit disponible à l'exécution.

<aside name="prop">

Le compilateur utilise "propriété" au lieu de "champ" ici parce que, rappelez-vous, Lox vous laisse aussi utiliser la syntaxe point pour accéder à une méthode sans l'appeler. "Propriété" est le terme général que nous utilisons pour nous référer à n'importe quelle entité nommée que vous pouvez accéder sur une instance. Les champs sont le sous-ensemble des propriétés qui sont soutenues par l'état de l'instance.

</aside>

Nous avons deux nouvelles formes d'expression -- getters et setters -- que cette seule fonction gère. Si nous voyons un signe égal après le nom de champ, cela doit être une expression set qui assigne à un champ. Mais nous ne permettons pas _toujours_ à un signe égal après le champ d'être compilé. Considérez :

```lox
a + b.c = 3
```

Ceci est syntaxiquement invalide selon la grammaire de Lox, ce qui signifie que notre implémentation Lox est obligée de détecter et rapporter l'erreur. Si `dot()` analysait silencieusement la partie `= 3`, nous interpréterions incorrectement le code comme si l'utilisateur avait écrit :

```lox
a + (b.c = 3)
```

Le problème est que le côté `=` d'une expression set a une précédence beaucoup plus basse que la partie `.`. L'analyseur peut appeler `dot()` dans un contexte qui est de trop haute précédence pour permettre à un setter d'apparaître. Pour éviter de permettre incorrectement cela, nous analysons et compilons la partie égale seulement quand `canAssign` est vrai. Si un jeton égal apparaît quand `canAssign` est faux, `dot()` le laisse tranquille et retourne. Dans ce cas, le compilateur finira par dérouler jusqu'à `parsePrecedence()`, qui s'arrête au `=` inattendu étant toujours assis comme le prochain jeton et rapporte une erreur.

Si nous trouvons un `=` dans un contexte où il _est_ permis, alors nous compilons l'expression qui suit. Après cela, nous émettons une nouvelle instruction <span name="set">`OP_SET_PROPERTY`</span>. Celle-là prend un seul opérande pour l'index du nom de la propriété dans la table de constantes. Si nous n'avons pas compilé une expression set, nous supposons que c'est un getter et émettons une instruction `OP_GET_PROPERTY`, qui prend aussi un opérande pour le nom de la propriété.

<aside name="set">

Vous ne pouvez pas _régler_ une propriété non-champ, donc je suppose que cette instruction aurait pu être `OP_SET_FIELD`, mais j'ai pensé que cela semblait plus joli d'être cohérent avec l'instruction get.

</aside>

Maintenant est un bon moment pour définir ces deux nouvelles instructions.

^code property-ops (1 before, 1 after)

Et ajouter le support pour les désassembler :

^code disassemble-property-ops (1 before, 1 after)

### Interpréter les expressions getter et setter

Glissant vers le runtime, nous commencerons avec les expressions get puisque celles-ci sont un peu plus simples.

^code interpret-get-property (1 before, 1 after)

Quand l'interpréteur atteint cette instruction, l'expression à la gauche du point a déjà été exécutée et l'instance résultante est au sommet de la pile. Nous lisons le nom de champ depuis la table de constantes et le cherchons dans la table de champs de l'instance. Si la table de hachage contient une entrée avec ce nom, nous dépilons l'instance et empilons la valeur de l'entrée comme le résultat.

Bien sûr, le champ pourrait ne pas exister. Dans Lox, nous avons défini cela comme étant une erreur d'exécution. Donc nous ajoutons une vérification pour cela et avortons si cela arrive.

^code get-undefined (3 before, 2 after)

<span name="field">Il</span> y a un autre mode d'échec à gérer que vous avez probablement remarqué. Le code ci-dessus suppose que l'expression à la gauche du point a bien évalué à une ObjInstance. Mais il n'y a rien empêchant un utilisateur d'écrire ceci :

```lox
var obj = "not an instance";
print obj.field;
```

Le programme de l'utilisateur est faux, mais la VM doit quand même gérer cela avec quelque grâce. Juste maintenant, elle mésinterprétera les bits de l'ObjString comme une ObjInstance et, je ne sais pas, prendra feu ou quelque chose définitivement pas gracieux.

Dans Lox, seules les instances sont permises d'avoir des champs. Vous ne pouvez pas fourrer un champ sur une chaîne ou un nombre. Donc nous avons besoin de vérifier que la valeur est une instance avant d'accéder à tout champ dessus.

<aside name="field">

Lox _pourrait_ supporter l'ajout de champs aux valeurs d'autres types. C'est notre langage et nous pouvons faire ce que nous voulons. Mais c'est probablement une mauvaise idée. Cela complique significativement l'implémentation de façons qui blessent la performance -- par exemple, l'internement de chaîne devient beaucoup plus dur.

Aussi, cela soulève des questions sémantiques noueuses autour de l'égalité et de l'identité des valeurs. Si j'attache un champ au nombre `3`, est-ce que le résultat de `1 + 2` a ce champ aussi ? Si oui, comment l'implémentation suit-elle cela ? Si non, est-ce que ces deux "trois" résultants sont toujours considérés égaux ?

</aside>

^code get-not-instance (1 before, 1 after)

Si la valeur sur la pile n'est pas une instance, nous rapportons une erreur d'exécution et sortons sûrement.

Bien sûr, les expressions get ne sont pas très utiles quand aucune instance n'a de champs. Pour cela nous avons besoin des setters.

^code interpret-set-property (2 before, 1 after)

Ceci est un peu plus complexe que `OP_GET_PROPERTY`. Quand cela s'exécute, le sommet de la pile a l'instance dont le champ est en train d'être réglé et au-dessus de cela, la valeur à stocker. Comme avant, nous lisons l'opérande de l'instruction et trouvons la chaîne du nom de champ. Utilisant cela, nous stockons la valeur au sommet de la pile dans la table de champs de l'instance.

Après cela est un peu de jonglerie de <span name="stack">pile</span>. Nous dépilons la valeur stockée, puis dépilons l'instance, et finalement empilons la valeur de retour. En d'autres termes, nous enlevons le _second_ élément de la pile tout en laissant le sommet seul. Un setter est lui-même une expression dont le résultat est la valeur assignée, donc nous avons besoin de laisser cette valeur sur la pile. Voici ce que je veux dire :

<aside name="stack">

Les opérations de pile vont comme ceci :

<img src="image/classes-and-instances/stack.png" alt="Dépilant deux valeurs et ensuite empilant la première valeur de retour sur la pile."/>

</aside>

```lox
class Toast {}
var toast = Toast();
print toast.jam = "grape"; // Affiche "grape".
```

Contrairement à lors de la lecture d'un champ, nous n'avons pas besoin de nous inquiéter que la table de hachage ne contienne pas le champ. Un setter crée implicitement le champ si nécessaire. Nous avons besoin de gérer l'utilisateur essayant incorrectement de stocker un champ sur une valeur qui n'est pas une instance.

^code set-not-instance (1 before, 1 after)

Exactement comme avec les expressions get, nous vérifions le type de la valeur et rapportons une erreur d'exécution si c'est invalide. Et, avec cela, le côté avec état du support de Lox pour la programmation orientée objet est en place. Donnez-lui un essai :

```lox
class Pair {}

var pair = Pair();
pair.first = 1;
pair.second = 2;
print pair.first + pair.second; // 3.
```

Ceci ne se sent pas vraiment très orienté _objet_. C'est plus comme une variante étrange, typée dynamiquement du C où les objets sont des sacs de données lâches semblables à des struct. Sorte d'un langage procédural dynamique. Mais c'est une grande étape en expressivité. Notre implémentation Lox laisse maintenant les utilisateurs agréger librement des données en de plus grandes unités. Dans le prochain chapitre, nous insufflerons la vie dans ces blobs inertes.

<div class="challenges">

## Défis

1.  Essayer d'accéder à un champ inexistant sur un objet avorte immédiatement la VM entière. L'utilisateur n'a aucun moyen de récupérer de cette erreur d'exécution, ni n'y a-t-il aucun moyen de voir si un champ existe _avant_ d'essayer d'y accéder. C'est à l'utilisateur d'assurer par lui-même que seuls des champs valides sont lus.

    Comment d'autres langages typés dynamiquement gèrent-ils les champs manquants ? Que pensez-vous que Lox devrait faire ? Implémentez votre solution.

2.  Les champs sont accédés à l'exécution par leur nom de _chaîne_. Mais ce nom doit toujours apparaître directement dans le code source comme un _jeton identifiant_. Un programme utilisateur ne peut pas impérativement construire une valeur chaîne et ensuite utiliser cela comme le nom d'un champ. Pensez-vous qu'ils devraient être capables de le faire ? Concevez une fonctionnalité de langage qui permet cela et implémentez-la.

3.  Inversement, Lox n'offre aucun moyen d'_enlever_ un champ d'une instance. Vous pouvez régler la valeur d'un champ à `nil`, mais l'entrée dans la table de hachage est toujours là. Comment d'autres langages gèrent-ils cela ? Choisissez et implémentez une stratégie pour Lox.

4.  Parce que les champs sont accédés par nom à l'exécution, travailler avec l'état d'instance est lent. C'est techniquement une opération en temps constant -- merci, tables de hachage -- mais les facteurs constants sont relativement grands. C'est un composant majeur de pourquoi les langages dynamiques sont plus lents que ceux typés statiquement.

    Comment les implémentations sophistiquées de langages typés dynamiquement gèrent-elles et optimisent-elles cela ?

</div>
