> Une fois nous étions des blobs dans la mer, et puis des poissons, et puis des lézards et des rats et
> puis des singes, et des centaines de choses entre les deux. Cette main était autrefois une nageoire,
> cette main avait autrefois des griffes ! Dans ma bouche humaine j'ai les dents pointues d'un loup
> et les dents ciseaux d'un lapin et les dents broyeuses d'une vache ! Notre sang est
> aussi salé que la mer dans laquelle nous avions l'habitude de vivre ! Quand nous sommes effrayés, les poils sur notre
> peau se dressent, juste comme ils le faisaient quand nous avions de la fourrure. Nous sommes l'histoire ! Tout ce que
> nous avons jamais été sur le chemin pour devenir nous, nous le sommes encore.
>
> <cite>Terry Pratchett, <em>Un chapeau de ciel</em></cite>

Pouvez-vous le croire ? Nous avons atteint le dernier chapitre de la [Partie II][part ii]. Nous avons presque fini avec notre premier interpréteur Lox. Le [chapitre précédent][previous chapter] était une grosse boule de fonctionnalités orientées objet entremêlées. Je ne pouvais pas les séparer les unes des autres, mais j'ai réussi à démêler un morceau. Dans ce chapitre, nous finirons le support des classes de Lox en ajoutant l'héritage.

[part ii]: une-promenade-dans-l-arbre.html
[previous chapter]: classes.html

L'héritage apparaît dans les langages orientés objet tout le chemin en arrière jusqu'au <span name="inherited">premier</span>, [Simula][]. Tôt au début, Kristen Nygaard et Ole-Johan Dahl ont remarqué des points communs à travers les classes dans les programmes de simulation qu'ils écrivaient. L'héritage leur a donné un moyen de réutiliser le code pour ces parties similaires.

[simula]: https://en.wikipedia.org/wiki/Simula

<aside name="inherited">

Vous pourriez dire que tous ces autres langages l'ont _hérité_ de Simula. Hey-ooo !
Je vais, euh, sortir.

</aside>

## Superclasses et Sous-classes

Étant donné que le concept est "héritage", vous espéreriez qu'ils choisiraient une métaphore cohérente et les appelleraient classes "parent" et "enfant", mais ce serait trop facile. Il y a longtemps, C. A. R. Hoare a inventé le terme "<span name="subclass">sous-classe</span>" pour faire référence à un type enregistrement qui raffine un autre type. Simula a emprunté ce terme pour faire référence à une _classe_ qui hérite d'une autre. Je ne pense pas que c'était avant que Smalltalk arrive que quelqu'un a retourné le préfixe Latin pour obtenir "superclasse" pour faire référence à l'autre côté de la relation. Depuis C++, vous entendez aussi classes "de base" et "dérivées". Je resterai principalement avec "superclasse" et "sous-classe".

<aside name="subclass">

"Super-" et "sub-" signifient "au-dessus" et "en dessous" en Latin, respectivement. Imaginez un arbre d'héritage comme un arbre généalogique avec la racine au sommet -- les sous-classes sont en dessous de leurs superclasses sur le diagramme. Plus généralement, "sub-" fait référence à des choses qui raffinent ou sont contenues par un concept plus général. En zoologie, une sous-classe est une catégorisation plus fine d'une plus large classe de choses vivantes.

En théorie des ensembles, un sous-ensemble est contenu par un super-ensemble plus large qui a tous les éléments du sous-ensemble et possiblement plus. La théorie des ensembles et les langages de programmation se rencontrent en théorie des types. Là, vous avez des "supertypes" et des "sous-types".

Dans les langages orientés objet typés statiquement, une sous-classe est aussi souvent un sous-type de sa superclasse. Disons que nous avons une superclasse Beignet et une sous-classe BostonCream. Chaque BostonCream est aussi une instance de Beignet, mais il peut y avoir des objets beignet qui ne sont pas des BostonCreams (comme des Crullers).

Pensez à un type comme l'ensemble de toutes les valeurs de ce type. L'ensemble de toutes les instances de Beignet contient l'ensemble de toutes les instances de BostonCream puisque chaque BostonCream est aussi un Beignet. Donc BostonCream est une sous-classe, et un sous-type, et ses instances sont un sous-ensemble. Tout s'aligne.

<img src="image/inheritance/doughnuts.png" alt="Boston cream &lt;: doughnut." />

</aside>

Notre première étape vers le support de l'héritage dans Lox est un moyen de spécifier une superclasse lors de la déclaration d'une classe. Il y a beaucoup de variété dans la syntaxe pour cela. C++ et C# placent un `:` après le nom de la sous-classe, suivi par le nom de la superclasse. Java utilise `extends` au lieu du deux-points. Python met la ou les superclasse(s) entre parenthèses après le nom de la classe. Simula met le nom de la superclasse _avant_ le mot-clé `class`.

Si tard dans le jeu, je préférerais ne pas ajouter un nouveau mot réservé ou token au lexer. Nous n'avons pas `extends` ou même `:`, donc nous suivrons Ruby et utiliserons un signe inférieur à (`<`).

```lox
class Doughnut {
  // Trucs généraux de beignet...
}

class BostonCream < Doughnut {
  // Trucs spécifiques au Boston Cream...
}
```

Pour faire entrer cela dans la grammaire, nous ajoutons une nouvelle clause optionnelle dans notre règle `classDecl` existante.

```ebnf
classDecl      → "class" IDENTIFIER ( "<" IDENTIFIER )?
                 "{" function* "}" ;
```

Après le nom de la classe, vous pouvez avoir un `<` suivi par le nom de la superclasse. La clause de superclasse est optionnelle parce que vous n'êtes pas _obligé_ d'avoir une superclasse. Contrairement à certains autres langages orientés objet comme Java, Lox n'a pas de classe racine "Object" dont tout hérite, donc quand vous omettez la clause de superclasse, la classe n'a _pas_ de superclasse, pas même une implicite.

Nous voulons capturer cette nouvelle syntaxe dans le nœud AST de déclaration de classe.

^code superclass-ast (1 before, 1 after)

Vous pourriez être surpris que nous stockions le nom de la superclasse comme une Expr.Variable, pas un Token. La grammaire restreint la clause de superclasse à un identifieur unique, mais à l'exécution, cet identifieur est évalué comme un accès variable. Envelopper le nom dans une Expr.Variable tôt dans le parseur nous donne un objet auquel le résolveur peut accrocher les informations de résolution.

Le nouveau code de parseur suit la grammaire directement.

^code parse-superclass (1 before, 1 after)

Une fois que nous avons (possiblement) parsé une déclaration de superclasse, nous la stockons dans l'AST.

^code construct-class-ast (2 before, 1 after)

Si nous n'avons pas parsé de clause de superclasse, l'expression superclasse sera `null`. Nous devrons nous assurer que les passes ultérieures vérifient cela. La première de celles-ci est le résolveur.

^code resolve-superclass (1 before, 2 after)

Le nœud AST de déclaration de classe a une nouvelle sous-expression, donc nous traversons dedans et résolvons cela. Puisque les classes sont habituellement déclarées au niveau supérieur, le nom de la superclasse sera très probablement une variable globale, donc cela ne fait habituellement rien d'utile. Cependant, Lox permet les déclarations de classe même à l'intérieur de blocs, donc il est possible que le nom de la superclasse fasse référence à une variable locale. Dans ce cas, nous devons nous assurer qu'elle est résolue.

Parce que même des programmeurs bien intentionnés écrivent parfois du code bizarre, il y a un cas limite idiot dont nous devons nous soucier pendant que nous sommes ici. Jetez un œil à ceci :

```lox
class Oops < Oops {}
```

Il n'y a aucun moyen que cela fasse quoi que ce soit d'utile, et si nous laissons le runtime essayer d'exécuter ceci, cela brisera l'attente que l'interpréteur a à propos du fait qu'il n'y ait pas de cycles dans la chaîne d'héritage. La chose la plus sûre est de détecter ce cas statiquement et de le rapporter comme une erreur.

^code inherit-self (2 before, 1 after)

En supposant que le code se résolve sans erreur, l'AST voyage vers l'interpréteur.

^code interpret-superclass (1 before, 1 after)

Si la classe a une expression superclasse, nous l'évaluons. Puisque cela pourrait potentiellement s'évaluer en une autre sorte d'objet, nous devons vérifier à l'exécution que la chose que nous voulons être la superclasse est en fait une classe. De mauvaises choses arriveraient si nous permettions du code comme :

```lox
var NotAClass = "I am totally not a class";

class Subclass < NotAClass {} // ?!
```

En supposant que cette vérification passe, nous continuons. Exécuter une déclaration de classe transforme la représentation syntaxique d'une classe -- son nœud AST -- en sa représentation à l'exécution, un objet LoxClass. Nous devons tuyauter la superclasse à travers vers cela aussi. Nous passons la superclasse au constructeur.

^code interpreter-construct-class (3 before, 1 after)

Le constructeur la stocke dans un champ.

^code lox-class-constructor (1 after)

Que nous déclarons ici :

^code lox-class-superclass-field (1 before, 1 after)

Avec cela, nous pouvons définir des classes qui sont des sous-classes d'autres classes. Maintenant, qu'est-ce que le fait d'avoir une superclasse _fait_ réellement ?

## Hériter des Méthodes

Hériter d'une autre classe signifie que tout ce qui est <span name="liskov">vrai</span> de la superclasse devrait être vrai, plus ou moins, de la sous-classe. Dans les langages typés statiquement, cela porte beaucoup d'implications. La sous-_classe_ doit aussi être un sous-_type_, et la disposition de la mémoire est contrôlée pour que vous puissiez passer une instance d'une sous-classe à une fonction attendant une superclasse et qu'elle puisse toujours accéder aux champs hérités correctement.

<aside name="liskov">

Un nom plus chic pour cette directive vague est le [_principe de substitution de Liskov_][liskov]. Barbara Liskov l'a introduit dans une conférence pendant la période formative de la programmation orientée objet.

[liskov]: https://en.wikipedia.org/wiki/Liskov_substitution_principle

</aside>

Lox est un langage typé dynamiquement, donc nos exigences sont beaucoup plus simples. Fondamentalement, cela signifie que si vous pouvez appeler une certaine méthode sur une instance de la superclasse, vous devriez être capable d'appeler cette méthode quand on vous donne une instance de la sous-classe. En d'autres termes, les méthodes sont héritées de la superclasse.

Cela s'aligne avec l'un des buts de l'héritage -- donner aux utilisateurs un moyen de réutiliser du code à travers les classes. Implémenter cela dans notre interpréteur est étonnamment facile.

^code find-method-recurse-superclass (3 before, 1 after)

C'est littéralement tout ce qu'il y a à faire. Quand nous cherchons une méthode sur une instance, si nous ne la trouvons pas sur la classe de l'instance, nous récursons vers le haut à travers la chaîne de superclasses et cherchons là. Donnez-lui un essai :

```lox
class Doughnut {
  cook() {
    print "Fry until golden brown.";
  }
}

class BostonCream < Doughnut {}

BostonCream().cook();
```

Et voilà, la moitié de nos fonctionnalités d'héritage sont complètes avec seulement trois lignes de code Java.

## Appeler les Méthodes de Superclasse

Dans `findMethod()` nous cherchons une méthode sur la classe courante _avant_ de marcher vers le haut de la chaîne de superclasses. Si une méthode avec le même nom existe à la fois dans la sous-classe et la superclasse, celle de la sous-classe prend la précédence ou **redéfinit** la méthode de la superclasse. Un peu comme comment les variables dans les portées internes masquent celles externes.

C'est super si la sous-classe veut _remplacer_ certain comportement de superclasse complètement. Mais, en pratique, les sous-classes veulent souvent _raffiner_ le comportement de la superclasse. Elles veulent faire un peu de travail spécifique à la sous-classe, mais aussi exécuter le comportement original de la superclasse aussi.

Cependant, puisque la sous-classe a redéfini la méthode, il n'y a aucun moyen de faire référence à celle originale. Si la méthode de sous-classe essaie de l'appeler par nom, elle frappera juste récursivement sa propre redéfinition. Nous avons besoin d'un moyen de dire "Appelle cette méthode, mais cherche-la directement sur ma superclasse et ignore ma redéfinition". Java utilise `super` pour cela, et nous utiliserons cette même syntaxe dans Lox. Voici un exemple :

```lox
class Doughnut {
  cook() {
    print "Fry until golden brown.";
  }
}

class BostonCream < Doughnut {
  cook() {
    super.cook();
    print "Pipe full of custard and coat with chocolate.";
  }
}

BostonCream().cook();
```

Si vous lancez ceci, cela devrait imprimer :

```text
Fry until golden brown.
Pipe full of custard and coat with chocolate.
```

Nous avons une nouvelle forme d'expression. Le mot-clé `super`, suivi par un point et un identifieur, cherche une méthode avec ce nom. Contrairement aux appels sur `this`, la recherche commence à la superclasse.

### Syntaxe

Avec `this`, le mot-clé fonctionne un peu comme une variable magique, et l'expression est ce token solitaire. Mais avec `super`, le `.` subséquent et le nom de propriété sont des parties inséparables de l'expression `super`. Vous ne pouvez pas avoir un token `super` nu tout seul.

```lox
print super; // Erreur de syntaxe.
```

Donc la nouvelle clause que nous ajoutons à la règle `primary` dans notre grammaire inclut l'accès de propriété aussi.

```ebnf
primary        → "true" | "false" | "nil" | "this"
               | NUMBER | STRING | IDENTIFIER | "(" expression ")"
               | "super" "." IDENTIFIER ;
```

Typiquement, une expression `super` est utilisée pour un appel de méthode, mais, comme avec les méthodes régulières, la liste d'arguments ne fait _pas_ partie de l'expression. Au lieu de cela, un _appel_ super est un _accès_ super suivi par un appel de fonction. Comme les autres appels de méthode, vous pouvez obtenir une poignée vers une méthode de superclasse et l'invoquer séparément.

```lox
var method = super.cook;
method();
```

Donc l'expression `super` elle-même contient seulement le token pour le mot-clé `super` et le nom de la méthode étant cherchée. Le <span name="super-ast">nœud d'arbre syntaxique</span> correspondant est ainsi :

^code super-expr (1 before, 1 after)

<aside name="super-ast">

Le code généré pour le nouveau nœud est dans l'[Annexe II][appendix-super].

[appendix-super]: appendix-ii.html#super-expression

</aside>

Suivant la grammaire, le nouveau code de parsing va à l'intérieur de notre méthode `primary()` existante.

^code parse-super (2 before, 2 after)

Un mot-clé `super` en tête nous dit que nous avons frappé une expression `super`. Après cela nous consommons le `.` attendu et le nom de méthode.

### Sémantique

Plus tôt, j'ai dit qu'une expression `super` commence la recherche de méthode depuis "la superclasse", mais _quelle_ superclasse ? La réponse naïve est la superclasse de `this`, l'objet sur lequel la méthode environnante a été appelée. Cela produit par coïncidence le bon comportement dans beaucoup de cas, mais ce n'est pas réellement correct. Contemplez :

```lox
class A {
  method() {
    print "A method";
  }
}

class B < A {
  method() {
    print "B method";
  }

  test() {
    super.method();
  }
}

class C < B {}

C().test();
```

Traduisez ce programme en Java, C#, ou C++ et il imprimera "A method", ce qui est ce que nous voulons que Lox fasse aussi. Quand ce programme s'exécute, à l'intérieur du corps de `test()`, `this` est une instance de C. La superclasse de C est B, mais ce n'est _pas_ là où la recherche devrait commencer. Si elle le faisait, nous frapperions la `method()` de B.

Au lieu de cela, la recherche devrait commencer sur la superclasse de _la classe contenant l'expression `super`_. Dans ce cas, puisque `test()` est défini à l'intérieur de B, l'expression `super` à l'intérieur devrait commencer la recherche sur la superclasse de _B_ -- A.

<span name="flow"></span>

<img src="image/inheritance/classes.png" alt="La chaîne d'appel s'écoulant à travers les classes." />

<aside name="flow">

Le flux d'exécution ressemble à quelque chose comme ceci :

1. Nous appelons `test()` sur une instance de C.

2. Cela entre dans la méthode `test()` héritée de B. Cela appelle `super.method()`.

3. La superclasse de B est A, donc cela enchaîne vers `method()` sur A, et le programme imprime "A method".

</aside>

Ainsi, afin d'évaluer une expression `super`, nous avons besoin de l'accès à la superclasse de la définition de classe entourant l'appel. Hélas, au point dans l'interpréteur où nous exécutons une expression `super`, nous n'avons pas cela facilement disponible.

Nous _pourrions_ ajouter un champ à LoxFunction pour stocker une référence à la LoxClass qui possède cette méthode. L'interpréteur garderait une référence à la LoxFunction s'exécutant actuellement pour que nous puissions la chercher plus tard quand nous frappons une expression `super`. De là, nous obtiendrions la LoxClass de la méthode, puis sa superclasse.

C'est beaucoup de tuyauterie. Dans le [dernier chapitre][], nous avions un problème similaire quand nous avions besoin d'ajouter le support pour `this`. Dans ce cas, nous avons utilisé notre mécanisme existant d'environnement et de fermeture pour stocker une référence à l'objet courant. Pourrions-nous faire quelque chose de similaire pour stocker la superclasse <span name="rhetorical">?</span> Eh bien, je ne serais probablement pas en train d'en parler si la réponse était non, donc... oui.

<aside name="rhetorical">

Est-ce que quelqu'un aime même les questions rhétoriques ?

</aside>

[last chapter]: classes.html

Une différence importante est que nous lions `this` quand la méthode est _accédée_. La même méthode peut être appelée sur différentes instances et chacune a besoin de son propre `this`. Avec les expressions `super`, la superclasse est une propriété fixe de la _déclaration de classe elle-même_. Chaque fois que vous évaluez une certaine expression `super`, la superclasse est toujours la même.

Cela signifie que nous pouvons créer l'environnement pour la superclasse une fois, quand la définition de classe est exécutée. Immédiatement avant que nous définissions les méthodes, nous faisons un nouvel environnement pour lier la superclasse de la classe au nom "super".

<img src="image/inheritance/superclass.png" alt="L'environnement de superclasse." />

Quand nous créons la représentation d'exécution LoxFunction pour chaque méthode, c'est l'environnement qu'elles captureront dans leur fermeture. Plus tard, quand une méthode est invoquée et `this` est lié, l'environnement de superclasse devient le parent pour l'environnement de la méthode, comme ceci :

<img src="image/inheritance/environments.png" alt="La chaîne d'environnement incluant l'environnement de superclasse." />

C'est beaucoup de machinerie, mais nous la traverserons une étape à la fois. Avant que nous puissions arriver à créer l'environnement à l'exécution, nous devons gérer la chaîne de portée correspondante dans le résolveur.

^code begin-super-scope (2 before, 2 after)

Si la déclaration de classe a une superclasse, alors nous créons une nouvelle portée entourant toutes ses méthodes. Dans cette portée, nous définissons le nom "super". Une fois que nous avons fini de résoudre les méthodes de la classe, nous jetons cette portée.

^code end-super-scope (2 before, 1 after)

C'est une optimisation mineure, mais nous créons seulement l'environnement de superclasse si la classe a réellement _une_ superclasse. Il n'y a pas de but à le créer quand il n'y a pas de superclasse puisqu'il n'y aurait pas de superclasse à stocker dedans de toute façon.

Avec "super" défini dans une chaîne de portée, nous sommes capables de résoudre l'expression `super` elle-même.

^code resolve-super-expr

Nous résolvons le token `super` exactement comme si c'était une variable. La résolution stocke le nombre de sauts le long de la chaîne d'environnement que l'interpréteur a besoin de marcher pour trouver l'environnement où la superclasse est stockée.

Ce code est reflété dans l'interpréteur. Quand nous évaluons une définition de sous-classe, nous créons un nouvel environnement.

^code begin-superclass-environment (6 before, 2 after)

À l'intérieur de cet environnement, nous stockons une référence à la superclasse -- l'objet LoxClass réel pour la superclasse que nous avons maintenant que nous sommes dans le runtime. Ensuite nous créons les LoxFunctions pour chaque méthode. Celles-ci vont capturer l'environnement courant -- celui où nous venons de lier "super" -- comme leur fermeture, s'accrochant à la superclasse comme nous en avons besoin. Une fois que c'est fait, nous dépilons l'environnement.

^code end-superclass-environment (2 before, 2 after)

Nous sommes prêts à interpréter les expressions `super` elles-mêmes. Il y a quelques pièces mobiles, donc nous construirons cette méthode en morceaux.

^code interpreter-visit-super

D'abord, le travail auquel nous avons mené. Nous cherchons la superclasse de la classe environnante en cherchant "super" dans l'environnement approprié.

Quand nous accédons à une méthode, nous avons aussi besoin de lier `this` à l'objet depuis lequel la méthode est accédée. Dans une expression comme `beignet.cook`, l'objet est tout ce que nous obtenons de l'évaluation de `beignet`. Dans une expression `super` comme `super.cook`, l'objet courant est implicitement le _même_ objet courant que nous utilisons. En d'autres termes, `this`. Même si nous cherchons la _méthode_ sur la superclasse, l'_instance_ est toujours `this`.

Malheureusement, à l'intérieur de l'expression `super`, nous n'avons pas de nœud pratique auquel le résolveur peut accrocher le nombre de sauts vers `this`. Heureusement, nous contrôlons la disposition des chaînes d'environnement. L'environnement où "this" est lié est toujours juste à l'intérieur de l'environnement où nous stockons "super".

^code super-find-this (2 before, 1 after)

Décaler la distance de un cherche "this" dans cet environnement interne. J'admets que ce n'est pas le code le plus <span name="elegant">élégant</span>, mais ça marche.

<aside name="elegant">

Écrire un livre qui inclut chaque ligne de code unique pour un programme signifie que je ne peux pas cacher les bidouilles en les laissant comme un "exercice pour le lecteur".

</aside>

Maintenant nous sommes prêts à chercher et lier la méthode, en commençant à la superclasse.

^code super-find-method (2 before, 1 after)

C'est presque exactement comme le code pour chercher une méthode d'une expression d'accès, sauf que nous appelons `findMethod()` sur la superclasse au lieu de sur la classe de l'objet courant.

C'est fondamentalement ça. Sauf, bien sûr, que nous pourrions _échouer_ à trouver la méthode. Donc nous vérifions cela aussi.

^code super-no-method (2 before, 2 after)

Vous l'avez ! Prenez cet exemple BostonCream de tout à l'heure et donnez-lui un essai. En supposant que vous et moi ayons tout fait correctement, cela devrait le frire d'abord, puis le fourrer avec de la crème.

### Usages invalides de super

Comme avec les fonctionnalités de langage précédentes, notre implémentation fait la bonne chose quand l'utilisateur écrit du code correct, mais nous n'avons pas blindé l'interpréteur contre le mauvais code. En particulier, considérez :

```lox
class Eclair {
  cook() {
    super.cook();
    print "Pipe full of crème pâtissière.";
  }
}
```

Cette classe a une expression `super`, mais pas de superclasse. À l'exécution, le code pour évaluer les expressions `super` suppose que "super" a été résolu avec succès et sera trouvé dans l'environnement. Cela va échouer ici parce qu'il n'y a pas d'environnement environnant pour la superclasse puisqu'il n'y a pas de superclasse. La JVM lancera une exception et mettra notre interpréteur à genoux.

Zut, il y a même des utilisations cassées plus simples de super :

```lox
super.notEvenInAClass();
```

Nous pourrions gérer des erreurs comme celles-ci à l'exécution en vérifiant pour voir si la recherche de "super" a réussi. Mais nous pouvons dire statiquement -- juste en regardant le code source -- que Eclair n'a pas de superclasse et ainsi aucune expression `super` ne marchera à l'intérieur. De même, dans le second exemple, nous savons que l'expression `super` n'est même pas à l'intérieur d'un corps de méthode.

Même si Lox est typé dynamiquement, cela ne veut pas dire que nous voulons différer _tout_ à l'exécution. Si l'utilisateur a fait une erreur, nous aimerions les aider à la trouver plus tôt plutôt que plus tard. Donc nous rapporterons ces erreurs statiquement, dans le résolveur.

D'abord, nous ajoutons un nouveau cas à l'enum que nous utilisons pour garder la trace de quel genre de classe entoure le code courant étant visité.

^code class-type-subclass (1 before, 1 after)

Nous utiliserons cela pour distinguer quand nous sommes à l'intérieur d'une classe qui a une superclasse contre une qui n'en a pas. Quand nous résolvons une déclaration de classe, nous définissons cela si la classe est une sous-classe.

^code set-current-subclass (1 before, 1 after)

Ensuite, quand nous résolvons une expression `super`, nous vérifions pour voir que nous sommes actuellement à l'intérieur d'une portée où c'est autorisé.

^code invalid-super (1 before, 1 after)

Si non -- oups ! -- l'utilisateur a fait une erreur.

## Conclusion

Nous l'avons fait ! Ce dernier bout de gestion d'erreur est le dernier morceau de code nécessaire pour compléter notre implémentation Java de Lox. C'est un réel <span name="superhero">accomplissement</span> et un dont vous devriez être fier. Dans la douzaine de chapitres passés et un millier ou presque de lignes de code, nous avons appris et implémenté...

- [tokens et analyse lexicale][4],
- [arbres syntaxiques abstraits][5],
- [analyse récursive descendante][6],
- expressions préfixes et infixes,
- représentation à l'exécution des objets,
- [interprétation de code utilisant le pattern Visiteur][7],
- [portée lexicale][8],
- chaînes d'environnement pour stocker les variables,
- [contrôle de flux][9],
- [fonctions avec paramètres][10],
- fermetures,
- [résolution de variable statique et détection d'erreur][11],
- [classes][12],
- constructeurs,
- champs,
- méthodes, et finalement,
- héritage.

[4]: analyse-lexicale.html
[5]: représentation-du-code.html
[6]: analyse-des-expressions.html
[7]: évaluation-des-expressions.html
[8]: instructions-et-état.html
[9]: contrôle-de-flux.html
[10]: fonctions.html
[11]: résolution-et-liaison.html
[12]: classes.html

<aside name="superhero">

<img src="image/inheritance/superhero.png" alt="Vous, étant votre mauvais soi." />

</aside>

Nous avons fait tout cela à partir de rien, avec aucune dépendance externe ou outils magiques. Juste vous et moi, nos éditeurs de texte respectifs, une paire de classes de collection de la bibliothèque standard Java, et le runtime JVM.

Cela marque la fin de la Partie II, mais pas la fin du livre. Prenez une pause. Peut-être écrivez quelques programmes Lox amusants et lancez-les dans votre interpréteur. (Vous pouvez vouloir ajouter quelques méthodes natives de plus pour des choses comme lire l'entrée utilisateur.) Quand vous serez rafraîchi et prêt, nous embarquerons pour notre [prochaine aventure][].

[prochaine aventure]: une-machine-virtuelle-a-bytecode.html

<div class="challenges">

## Défis

1.  Lox supporte seulement l'_héritage simple_ -- une classe peut avoir une seule superclasse et c'est le seul moyen de réutiliser des méthodes à travers les classes. D'autres langages ont exploré une variété de façons de réutiliser et partager plus librement des capacités à travers les classes : mixins, traits, héritage multiple, héritage virtuel, méthodes d'extension, etc.

    Si vous deviez ajouter une certaine fonctionnalité le long de ces lignes à Lox, laquelle choisiriez-vous et pourquoi ? Si vous vous sentez courageux (et vous devriez l'être à ce point), allez-y et ajoutez-la.

2.  Dans Lox, comme dans la plupart des autres langages orientés objet, quand nous cherchons une méthode, nous commençons au bas de la hiérarchie de classe et travaillons notre chemin vers le haut -- une méthode de sous-classe est préférée sur celle d'une superclasse. Afin d'atteindre la méthode de superclasse depuis l'intérieur d'une méthode de redéfinition, vous utilisez `super`.

    Le langage [BETA][] prend l'[approche opposée][inner]. Quand vous appelez une méthode, elle commence au _sommet_ de la hiérarchie de classe et travaille vers le _bas_. Une méthode de superclasse gagne sur une méthode de sous-classe. Afin d'atteindre la méthode de sous-classe, la méthode de superclasse peut appeler `inner`, qui est en quelque sorte comme l'inverse de `super`. Cela enchaîne vers la prochaine méthode en bas de la hiérarchie.

    La méthode de superclasse contrôle quand et où il est permis à la sous-classe de raffiner son comportement. Si la méthode de superclasse n'appelle pas `inner` du tout, alors la sous-classe n'a aucun moyen de redéfinir ou modifier le comportement de la superclasse.

    Enlevez le comportement actuel de redéfinition et de `super` de Lox et remplacez-le avec la sémantique de BETA. En bref :
    - Quand une méthode est appelée sur une classe, préférez la méthode _la plus haute_ sur la chaîne d'héritage de la classe.

    - À l'intérieur du corps d'une méthode, un appel à `inner` cherche une méthode avec le même nom dans la sous-classe la plus proche le long de la chaîne d'héritage entre la classe contenant le `inner` et la classe de `this`. S'il n'y a pas de méthode correspondante, l'appel `inner` ne fait rien.

    Par exemple :

    ```lox
    class Doughnut {
      cook() {
        print "Fry until golden brown.";
        inner();
        print "Place in a nice box.";
      }
    }

    class BostonCream < Doughnut {
      cook() {
        print "Pipe full of custard and coat with chocolate.";
      }
    }

    BostonCream().cook();
    ```

    Cela devrait imprimer :

    ```text
    Fry until golden brown.
    Pipe full of custard and coat with chocolate.
    Place in a nice box.
    ```

3.  Dans le chapitre où j'ai présenté Lox, [je vous ai mis au défi][challenge] d'arriver avec une paire de fonctionnalités dont vous pensez que le langage manque. Maintenant que vous savez comment construire un interpréteur, implémentez l'une de ces fonctionnalités.

[challenge]: le-langage-lox.html#defis
[inner]: http://journal.stuffwithstuff.com/2012/12/19/the-impoliteness-of-overriding-methods/
[beta]: https://beta.cs.au.dk/

</div>
