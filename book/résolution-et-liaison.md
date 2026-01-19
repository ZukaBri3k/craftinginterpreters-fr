> Une fois de temps en temps vous vous trouvez dans une situation étrange. Vous y entrez par
> degrés et de la façon la plus naturelle mais, quand vous êtes juste au milieu de
> celle-ci, vous êtes soudainement étonné et vous demandez comment diable tout cela est
> arrivé.
>
> <cite>Thor Heyerdahl, <em>Kon-Tiki</em></cite>

Oh, non ! Notre implémentation de langage prend l'eau ! Il y a longtemps quand nous avons [ajouté les variables et les blocs][statements], nous avions une portée propre et étanche. Mais quand nous avons [plus tard ajouté les fermetures][functions], un trou s'est ouvert dans notre interpréteur autrefois imperméable. La plupart des vrais programmes sont peu susceptibles de glisser à travers ce trou, mais en tant qu'implémenteurs de langage, nous faisons le vœu sacré de nous soucier de la correction même dans les coins les plus profonds, les plus humides de la sémantique.

[statements]: statements-and-state.html
[functions]: functions.html

Nous passerons ce chapitre entier à explorer cette fuite, et ensuite à la colmater soigneusement. Dans le processus, nous gagnerons une compréhension plus rigoureuse de la portée lexicale telle qu'utilisée par Lox et d'autres langages dans la tradition C. Nous aurons aussi une chance d'apprendre à propos de l'_analyse sémantique_ -- une technique puissante pour extraire du sens du code source de l'utilisateur sans avoir à l'exécuter.

## Portée Statique

Un rafraîchissement rapide : Lox, comme la plupart des langages modernes, utilise une portée _lexicale_. Cela signifie que vous pouvez deviner à quelle déclaration un nom de variable fait référence juste en lisant le texte du programme. Par exemple :

```lox
var a = "externe";
{
  var a = "interne";
  print a;
}
```

Ici, nous savons que le `a` qui est imprimé est la variable déclarée sur la ligne précédente, et non la globale. Exécuter le programme n'affecte pas -- ne _peut pas_ affecter -- cela. Les règles de portée font partie de la sémantique _statique_ du langage, ce qui est pourquoi elles sont aussi appelées _portée statique_.

Je n'ai pas épelé ces règles de portée, mais maintenant est le moment pour la <span name="precise">précision</span> :

<aside name="precise">

Ceci n'est toujours nulle part aussi précis qu'une vraie spécification de langage. Ces docs doivent être si explicites que même un Martien ou un programmeur carrément malicieux serait forcé d'implémenter la sémantique correcte pourvu qu'il suive la lettre de la spec.

Cette exactitude est importante quand un langage peut être implémenté par des entreprises concurrentes qui veulent que leur produit soit incompatible avec les autres pour verrouiller les clients sur leur plateforme. Pour ce livre, nous pouvons heureusement ignorer ces types de manigances louches.

</aside>

**Un usage de variable fait référence à la déclaration précédente avec le même nom dans la portée la plus interne qui entoure l'expression où la variable est utilisée.**

Il y a beaucoup à déballer là-dedans :

- Je dis "usage de variable" au lieu de "expression de variable" pour couvrir à la fois les expressions de variable et les affectations. De même avec "expression où la variable est utilisée".

- "Précédente" signifie apparaissant avant _dans le texte du programme_.

    ```lox
    var a = "externe";
    {
      print a;
      var a = "interne";
    }
    ```

    Ici, le `a` qui est imprimé est l'externe puisqu'il apparaît <span name="hoisting">avant</span> l'instruction `print` qui l'utilise. Dans la plupart des cas, dans du code en ligne droite, la déclaration précédant dans le _texte_ précédera aussi l'usage dans le _temps_. Mais ce n'est pas toujours vrai. Comme nous le verrons, les fonctions peuvent différer un morceau de code de telle sorte que son exécution _temporelle dynamique_ ne reflète plus l'ordre _textuel statique_.

      <aside name="hoisting">

    En JavaScript, les variables déclarées utilisant `var` sont implicitement "hissées" (hoisted) au début du bloc. Tout usage de ce nom dans le bloc fera référence à cette variable, même si l'usage apparaît avant la déclaration. Quand vous écrivez ceci en JavaScript :

    ```js
    {
        console.log(a);
        var a = "valeur";
    }
    ```

    Cela se comporte comme :

    ```js
    {
        var a; // Hissage.
        console.log(a);
        a = "valeur";
    }
    ```

    Cela signifie que dans certains cas vous pouvez lire une variable avant que son initialiseur ait tourné -- une source ennuyeuse de bugs. La syntaxe alternative `let` pour déclarer des variables a été ajoutée plus tard pour adresser ce problème.

      </aside>

- "La plus interne" est là à cause de notre bon ami le masquage (shadowing). Il peut y avoir plus d'une variable avec le nom donné dans les portées environnantes, comme dans :

    ```lox
    var a = "externe";
    {
      var a = "interne";
      print a;
    }
    ```

    Notre règle désambiguïse ce cas en disant que la portée la plus interne gagne.

Puisque cette règle ne fait aucune mention d'aucun comportement à l'exécution, elle implique qu'une expression de variable fait toujours référence à la même déclaration à travers l'exécution entière du programme. Notre interpréteur jusqu'ici implémente _surtout_ la règle correctement. Mais quand nous avons ajouté les fermetures, une erreur s'est glissée.

```lox
var a = "global";
{
  fun showA() {
    print a;
  }

  showA();
  var a = "bloc";
  showA();
}
```

<span name="tricky">Avant</span> que vous ne tapiez ceci et l'exécutiez, décidez ce que vous pensez qu'il _devrait_ imprimer.

<aside name="tricky">

Je sais, c'est un programme totalement pathologique, artificiel. C'est juste _bizarre_. Aucune personne raisonnable n'écrirait jamais de code comme ça. Hélas, plus de votre vie que vous ne l'attendriez sera passée à gérer des snippets bizarres de code comme ça si vous restez dans le jeu des langages de programmation pour longtemps.

</aside>

OK... vous l'avez ? Si vous êtes familier avec les fermetures dans d'autres langages, vous attendrez qu'il imprime "global" deux fois. Le premier appel à `showA()` devrait définitivement imprimer "global" puisque nous n'avons même pas encore atteint la déclaration du `a` interne. Et par notre règle qu'une expression de variable se résout toujours à la même variable, cela implique que le second appel à `showA()` devrait imprimer la même chose.

Hélas, il imprime :

```text
global
bloc
```

Laissez-moi souligner que ce programme ne réassigne jamais aucune variable et contient seulement une seule instruction `print`. Pourtant, d'une certaine manière, cette instruction `print` pour une variable jamais assignée imprime deux valeurs différentes à différents points dans le temps. Nous avons définitivement cassé quelque chose quelque part.

### Portées et environnements mutables

Dans notre interpréteur, les environnements sont la manifestation dynamique des portées statiques. Les deux restent la plupart du temps synchronisés l'un avec l'autre -- nous créons un nouvel environnement quand nous entrons dans une nouvelle portée, et le jetons quand nous quittons la portée. Il y a une autre opération que nous effectuons sur les environnements : lier une variable dans l'un d'eux. C'est là que notre bug réside.

Parcourons cet exemple problématique et voyons à quoi ressemblent les environnements à chaque étape. D'abord, nous déclarons `a` dans la portée globale.

<img src="image/resolving-and-binding/environment-1.png" alt="L'environnement global avec 'a' défini dedans." />

Cela nous donne un seul environnement avec une seule variable dedans. Ensuite nous entrons dans le bloc et exécutons la déclaration de `showA()`.

<img src="image/resolving-and-binding/environment-2.png" alt="Un environnement de bloc lié à celui global." />

Nous obtenons un nouvel environnement pour le bloc. Dans celui-ci, nous déclarons un nom, `showA`, qui est lié à l'objet LoxFunction que nous créons pour représenter la fonction. Cet objet a un champ `closure` qui capture l'environnement où la fonction a été déclarée, donc il a une référence en arrière vers l'environnement pour le bloc.

Maintenant nous appelons `showA()`.

<img src="image/resolving-and-binding/environment-3.png" alt="Un environnement vide pour le corps de showA() lié aux deux précédents. 'a' est résolu dans l'environnement global." />

L'interpréteur crée dynamiquement un nouvel environnement pour le corps de la fonction `showA()`. Il est vide puisque cette fonction ne déclare aucune variable. Le parent de cet environnement est la fermeture de la fonction -- l'environnement du bloc externe.

À l'intérieur du corps de `showA()`, nous imprimons la valeur de `a`. L'interpréteur cherche cette valeur en parcourant la chaîne d'environnements. Il va tout le chemin jusqu'à l'environnement global avant de la trouver là et d'imprimer `"global"`. Super.

Ensuite, nous déclarons le second `a`, cette fois à l'intérieur du bloc.

<img src="image/resolving-and-binding/environment-4.png" alt="L'environnement de bloc a à la fois 'a' et 'showA' maintenant." />

C'est dans le même bloc -- la même portée -- que `showA()`, donc il va dans le même environnement, qui est aussi le même environnement auquel la fermeture de `showA()` fait référence. C'est là que ça devient intéressant. Nous appelons `showA()` à nouveau.

<img src="image/resolving-and-binding/environment-5.png" alt="Un environnement vide pour le corps de showA() lié aux deux précédents. 'a' est résolu dans l'environnement de bloc." />

Nous créons un nouvel environnement vide pour le corps de `showA()` encore une fois, le branchons à cette fermeture, et lançons le corps. Quand l'interpréteur parcourt la chaîne d'environnements pour trouver `a`, il découvre maintenant le _nouveau_ `a` dans l'environnement de bloc. Bouh.

J'ai choisi d'implémenter les environnements d'une façon dont j'espérais qu'elle s'accorderait avec votre intuition informelle autour des portées. Nous avons tendance à considérer tout le code à l'intérieur d'un bloc comme étant à l'intérieur de la même portée, donc notre interpréteur utilise un seul environnement pour représenter cela. Chaque environnement est une table de hachage mutable. Quand une nouvelle variable locale est déclarée, elle est ajoutée à l'environnement existant pour cette portée.

Cette intuition, comme beaucoup dans la vie, n'est pas tout à fait juste. Un bloc n'est pas nécessairement tout la même portée. Considérez :

```lox
{
  var a;
  // 1.
  var b;
  // 2.
}
```

À la première ligne marquée, seul `a` est dans la portée. À la seconde ligne, les deux `a` et `b` le sont. Si vous définissez une "portée" comme étant un ensemble de déclarations, alors celles-ci ne sont clairement pas la même portée -- elles ne contiennent pas les mêmes déclarations. C'est comme si chaque instruction `var` <span name="split">scindait</span> le bloc en deux portées séparées, la portée avant que la variable ne soit déclarée et celle après, qui inclut la nouvelle variable.

<aside name="split">

Certains langages rendent cette scission explicite. En Scheme et ML, quand vous déclarez une variable locale utilisant `let`, vous délimitez aussi le code subséquent où la nouvelle variable est dans la portée. Il n'y a pas de "reste du bloc" implicite.

</aside>

Mais dans notre implémentation, les environnements agissent bien comme si le bloc entier était une seule portée, juste une portée qui change au fil du temps. Les fermetures n'aiment pas ça. Quand une fonction est déclarée, elle capture une référence à l'environnement courant. La fonction _devrait_ capturer un instantané figé de l'environnement _tel qu'il existait au moment où la fonction a été déclarée_. Mais au lieu de cela, dans le code Java, elle a une référence à l'objet environnement mutable réel. Quand une variable est plus tard déclarée dans la portée à laquelle cet environnement correspond, la fermeture voit la nouvelle variable, même si la déclaration ne précède _pas_ la fonction.

### Environnements persistants

Il y a un style de programmation qui utilise ce qu'on appelle des **structures de données persistantes**. Contrairement aux structures de données molles avec lesquelles vous êtes familier en programmation impérative, une structure de données persistante ne peut jamais être directement modifiée. Au lieu de cela, toute "modification" à une structure existante produit un <span name="copy">tout</span> nouvel objet qui contient toutes les données originales et la nouvelle modification. L'original est laissé inchangé.

<aside name="copy">

Cela sonne comme si ça pouvait gaspiller des tonnes de mémoire et de temps à copier la structure pour chaque opération. En pratique, les structures de données persistantes partagent la plupart de leurs données entre les différentes "copies".

</aside>

Si nous devions appliquer cette technique à Environment, alors chaque fois que vous déclariez une variable cela renverrait un _nouvel_ environnement qui contenait toutes les variables précédemment déclarées avec le nouveau nom. Déclarer une variable ferait la "scission" implicite où vous avez un environnement avant que la variable ne soit déclarée et un après :

<img src="image/resolving-and-binding/split.png" alt="Environnements séparés avant et après que la variable soit déclarée." />

Une fermeture retient une référence à l'instance Environment en jeu quand la fonction a été déclarée. Puisque toutes les déclarations ultérieures dans ce bloc produiraient de nouveaux objets Environment, la fermeture ne verrait pas les nouvelles variables et notre bug serait corrigé.

C'est une façon légitime de résoudre le problème, et c'est la façon classique d'implémenter les environnements dans les interpréteurs Scheme. Nous pourrions faire cela pour Lox, mais cela signifierait revenir en arrière et changer une pile de code existant.

Je ne vous traînerai pas à travers ça. Nous garderons la façon dont nous représentons les environnements la même. Au lieu de rendre les données plus statiquement structurées, nous cuirons la résolution statique dans l'_opération_ d'accès elle-même.

## Analyse Sémantique

Notre interpréteur **résout** une variable -- traque à quelle déclaration elle fait référence -- chaque fois que l'expression de variable est évaluée. Si cette variable est emmaillotée à l'intérieur d'une boucle qui tourne mille fois, cette variable est re-résolue mille fois.

Nous savons que la portée statique signifie qu'un usage de variable se résout toujours à la même déclaration, ce qui peut être déterminé juste en regardant le texte. Étant donné cela, pourquoi le faisons-nous dynamiquement à chaque fois ? Le faire n'ouvre pas seulement le trou qui mène à notre bug ennuyeux, c'est aussi inutilement lent.

Une meilleure solution est de résoudre chaque utilisation de variable _une fois_. Écrire un morceau de code qui inspecte le programme de l'utilisateur, trouve chaque variable mentionnée, et devine à quelle déclaration chacune fait référence. Ce processus est un exemple d'une **analyse sémantique**. Là où un parseur dit seulement si un programme est grammaticalement correct (une analyse _syntaxique_), l'analyse sémantique va plus loin et commence à deviner ce que les pièces du programme signifient réellement. Dans ce cas, notre analyse résoudra les liaisons de variables. Nous saurons non seulement qu'une expression _est_ une variable, mais _quelle_ variable elle est.

Il y a beaucoup de façons dont nous pourrions stocker la liaison entre une variable et sa déclaration. Quand nous arriverons à l'interpréteur C pour Lox, nous aurons une façon _beaucoup_ plus efficace de stocker et d'accéder aux variables locales. Mais pour jlox, je veux minimiser les dommages collatéraux que nous infligeons à notre base de code existante. Je détesterais jeter un tas de code surtout bon.

Au lieu de cela, nous stockerons la résolution d'une façon qui tire le meilleur parti de notre classe Environment existante. Rappelez-vous comment les accès de `a` sont interprétés dans l'exemple problématique.

<img src="image/resolving-and-binding/environment-3.png" alt="Un environnement vide pour le corps de showA() lié aux deux précédents. 'a' est résolu dans l'environnement global." />

Dans la première évaluation (correcte), nous regardons trois environnements dans la chaîne avant de trouver la déclaration globale de `a`. Ensuite, quand le `a` interne est plus tard déclaré dans une portée de bloc, il masque le global.

<img src="image/resolving-and-binding/environment-5.png" alt="Un environnement vide pour le corps de showA() lié aux deux précédents. 'a' est résolu dans l'environnement de bloc." />

La recherche suivante parcourt la chaîne, trouve `a` dans le _second_ environnement et s'arrête là. Chaque environnement correspond à une seule portée lexicale où les variables sont déclarées. Si nous pouvions nous assurer qu'une recherche de variable parcourait toujours le _même_ nombre de liens dans la chaîne d'environnement, cela assurerait qu'elle trouve la même variable dans la même portée à chaque fois.

Pour "résoudre" un usage de variable, nous avons seulement besoin de calculer à combien de "sauts" la variable déclarée sera dans la chaîne d'environnement. La question intéressante est _quand_ faire ce calcul -- ou, mis différemment, où dans l'implémentation de notre interpréteur bourrons-nous le code pour cela ?

Puisque nous calculons une propriété statique basée sur la structure du code source, la réponse évidente est dans le parseur. C'est la maison traditionnelle, et c'est où nous la mettrons plus tard dans clox. Cela marcherait ici aussi, mais je veux une excuse pour vous montrer une autre technique. Nous écrirons notre résolveur comme une passe séparée.

### Une passe de résolution de variable

Après que le parseur produit l'arbre syntaxique, mais avant que l'interpréteur ne commence à l'exécuter, nous ferons une seule marche sur l'arbre pour résoudre toutes les variables qu'il contient. Des passes supplémentaires entre le parsing et l'exécution sont courantes. Si Lox avait des types statiques, nous pourrions glisser un vérificateur de type là-dedans. Les optimisations sont souvent implémentées dans des passes séparées comme ça aussi. Fondamentalement, tout travail qui ne repose pas sur l'état qui est seulement disponible à l'exécution peut être fait de cette façon.

Notre passe de résolution de variable fonctionne comme une sorte de mini-interpréteur. Elle parcourt l'arbre, visitant chaque nœud, mais une analyse statique est différente d'une exécution dynamique :

- **Il n'y a pas d'effets de bord.** Quand l'analyse statique visite une instruction print, elle n'imprime rien réellement. Les appels aux fonctions natives ou autres opérations qui atteignent le monde extérieur sont bouchonnés et n'ont aucun effet.

- **Il n'y a pas de contrôle de flux.** Les boucles sont visitées seulement <span name="fix">une fois</span>. Les deux branches sont visitées dans les instructions `if`. Les opérateurs logiques ne sont pas court-circuités.

<aside name="fix">

La résolution de variable touche chaque nœud une fois, donc sa performance est _O(n)_ où _n_ est le nombre de nœuds d'arbre syntaxique. Des analyses plus sophistiquées peuvent avoir une plus grande complexité, mais la plupart sont soigneusement conçues pour être linéaires ou pas loin de l'être. C'est un faux pas embarrassant si votre compilateur devient exponentiellement plus lent à mesure que le programme de l'utilisateur grandit.

</aside>

## Une Classe Résolveur

Comme tout en Java, notre passe de résolution de variable est incarnée dans une classe.

^code resolver

Puisque le résolveur a besoin de visiter chaque nœud dans l'arbre syntaxique, il implémente l'abstraction visiteur que nous avons déjà en place. Seuls quelques types de nœuds sont intéressants quand il s'agit de résoudre les variables :

- Une instruction de bloc introduit une nouvelle portée pour les instructions qu'elle contient.

- Une déclaration de fonction introduit une nouvelle portée pour son corps et lie ses paramètres dans cette portée.

- Une déclaration de variable ajoute une nouvelle variable à la portée courante.

- Les expressions de variable et d'affectation ont besoin d'avoir leurs variables résolues.

Le reste des nœuds ne fait rien de spécial, mais nous avons toujours besoin d'implémenter des méthodes visit pour eux qui traversent dans leurs sous-arbres. Même si une expression `+` n'a _elle-même_ aucune variable à résoudre, l'un ou l'autre de ses opérandes pourrait en avoir.

### Résoudre les blocs

Nous commençons avec les blocs puisqu'ils créent les portées locales où toute la magie se produit.

^code visit-block-stmt

Ceci commence une nouvelle portée, traverse dans les instructions à l'intérieur du bloc, et ensuite jette la portée. Le truc fun vit dans ces méthodes assistantes. Nous commençons avec la simple.

^code resolve-statements

Ceci parcourt une liste d'instructions et résout chacune. Elle appelle à son tour :

^code resolve-stmt

Pendant que nous y sommes, ajoutons une autre surcharge dont nous aurons besoin plus tard pour résoudre une expression.

^code resolve-expr

Ces méthodes sont similaires aux méthodes `evaluate()` et `execute()` dans Interpreter -- elles se retournent et appliquent le pattern Visitor au nœud d'arbre syntaxique donné.

Le vrai comportement intéressant est autour des portées. Une nouvelle portée de bloc est créée comme ceci :

^code begin-scope

Les portées lexicales s'imbriquent à la fois dans l'interpréteur et le résolveur. Elles se comportent comme une pile. L'interpréteur implémente cette pile en utilisant une liste chaînée -- la chaîne d'objets Environment. Dans le résolveur, nous utilisons une Stack Java réelle.

^code scopes-field (1 before, 2 after)

Ce champ garde une trace de la pile de portées actuellement, uh, dans la portée. Chaque élément dans la pile est une Map représentant une seule portée de bloc. Les clés, comme dans Environment, sont des noms de variable. Les valeurs sont des Booléens, pour une raison que j'expliquerai bientôt.

La pile de portée est seulement utilisée pour les portées de bloc locales. Les variables déclarées au niveau supérieur dans la portée globale ne sont pas suivies par le résolveur puisqu'elles sont plus dynamiques dans Lox. Quand nous résolvons une variable, si nous ne pouvons pas la trouver dans la pile de portées locales, nous supposons qu'elle doit être globale.

Puisque les portées sont stockées dans une pile explicite, en sortir une est direct.

^code end-scope

Maintenant nous pouvons empiler et dépiler une pile de portées vides. Mettons des choses dedans.

### Résoudre les déclarations de variable

Résoudre une déclaration de variable ajoute une nouvelle entrée à la map de la portée la plus interne actuelle. Cela semble simple, mais il y a une petite danse que nous devons faire.

^code visit-var-stmt

Nous divisons la liaison en deux étapes, déclarer puis définir, afin de gérer des cas limites drôles comme celui-ci :

```lox
var a = "externe";
{
  var a = a;
}
```

Qu'arrive-t-il quand l'initialiseur pour une variable locale fait référence à une variable avec le même nom que la variable étant déclarée ? Nous avons quelques options :

1.  **Lancer l'initialiseur, puis mettre la nouvelle variable dans la portée.** Ici, la nouvelle locale `a` serait initialisée avec "externe", la valeur de la _globale_. En d'autres termes, la déclaration précédente se "désucrerait" en :

    ```lox
    var temp = a; // Lance l'initialiseur.
    var a;        // Déclare la variable.
    a = temp;     // L'initialise.
    ```

2.  **Mettre la nouvelle variable dans la portée, puis lancer l'initialiseur.** Cela signifie que vous pourriez observer une variable avant qu'elle soit initialisée, donc nous aurions besoin de deviner quelle valeur elle aurait alors. Probablement `nil`. Cela signifie que la nouvelle locale `a` serait ré-initialisée à sa propre valeur implicitement initialisée, `nil`. Maintenant le "désucrage" ressemblerait à :

    ```lox
    var a; // Définit la variable.
    a = a; // Lance l'initialiseur.
    ```

3.  **Faire une erreur de référencer une variable dans son initialiseur.** Faire échouer l'interpréteur soit à la compilation soit à l'exécution si un initialiseur mentionne la variable étant initialisée.

Est-ce que l'une ou l'autre de ces deux premières options ressemble à quelque chose qu'un utilisateur _veut_ réellement ? Le masquage est rare et souvent une erreur, donc initialiser une variable masquante basée sur la valeur de la masquée semble peu susceptible d'être délibéré.

La seconde option est encore moins utile. La nouvelle variable aura _toujours_ la valeur `nil`. Il n'y a jamais aucun intérêt à la mentionner par son nom. Vous pourriez utiliser un `nil` explicite à la place.

Puisque les deux premières options sont susceptibles de masquer des erreurs utilisateur, nous prendrons la troisième. De plus, nous en ferons une erreur de compilation au lieu d'une à l'exécution. De cette façon, l'utilisateur est alerté du problème avant qu'aucun code ne soit lancé.

Afin de faire cela, alors que nous visitons les expressions, nous avons besoin de savoir si nous sommes à l'intérieur de l'initialiseur pour une certaine variable. Nous faisons cela en divisant la liaison en deux étapes. La première est de la **déclarer**.

^code declare

La déclaration ajoute la variable à la portée la plus interne pour qu'elle masque toute externe et pour que nous sachions que la variable existe. Nous la marquons comme "pas encore prête" en liant son nom à `false` dans la map de portée. La valeur associée à une clé dans la map de portée représente si oui ou non nous avons fini de résoudre l'initialiseur de cette variable.

Après avoir déclaré la variable, nous résolvons son expression d'initialiseur dans cette même portée où la nouvelle variable existe maintenant mais est indisponible. Une fois que l'expression d'initialiseur est finie, la variable est prête pour le prime time. Nous faisons cela en la **définissant**.

^code define

Nous mettons la valeur de la variable dans la map de portée à `true` pour la marquer comme pleinement initialisée et disponible pour l'utilisation. Elle est vivante !

### Résoudre les expressions de variable

Les déclarations de variable -- et les déclarations de fonction, auxquelles nous arriverons -- écrivent dans les maps de portée. Ces maps sont lues quand nous résolvons les expressions de variable.

^code visit-variable-expr

D'abord, nous vérifions pour voir si la variable est accédée à l'intérieur de son propre initialiseur. C'est là que les valeurs dans la map de portée entrent en jeu. Si la variable existe dans la portée courante mais que sa valeur est `false`, cela signifie que nous l'avons déclarée mais pas encore définie. Nous rapportons cette erreur.

Après cette vérification, nous résolvons réellement la variable elle-même en utilisant cet assistant :

^code resolve-local

Ceci ressemble, pour une bonne raison, beaucoup au code dans Environment pour évaluer une variable. Nous commençons à la portée la plus interne et travaillons vers l'extérieur, cherchant dans chaque map un nom correspondant. Si nous trouvons la variable, nous la résolvons, en passant le nombre de portées entre la portée la plus interne courante et la portée où la variable a été trouvée. Donc, si la variable a été trouvée dans la portée courante, nous passons 0. Si c'est dans la portée immédiatement englobante, 1. Vous avez l'idée.

Si nous parcourons toutes les portées de bloc et ne trouvons jamais la variable, nous la laissons non résolue et supposons qu'elle est globale. Nous arriverons à l'implémentation de cette méthode `resolve()` un peu plus tard. Pour l'instant, continuons à mouliner à travers les autres nœuds de syntaxe.

### Résoudre les expressions d'affectation

L'autre expression qui référence une variable est l'affectation. En résoudre une ressemble à ceci :

^code visit-assign-expr

D'abord, nous résolvons l'expression pour la valeur assignée au cas où elle contient aussi des références à d'autres variables. Ensuite nous utilisons notre méthode `resolveLocal()` existante pour résoudre la variable à qui on assigne.

### Résoudre les déclarations de fonction

Finalement, les fonctions. Les fonctions lient à la fois des noms et introduisent une portée. Le nom de la fonction elle-même est lié dans la portée environnante où la fonction est déclarée. Quand nous entrons dans le corps de la fonction, nous lions aussi ses paramètres dans cette portée de fonction interne.

^code visit-function-stmt

Similaire à `visitVariableStmt()`, nous déclarons et définissons le nom de la fonction dans la portée courante. Contrairement aux variables, cependant, nous définissons le nom avidement, avant de résoudre le corps de la fonction. Cela laisse une fonction faire référence récursivement à elle-même à l'intérieur de son propre corps.

Ensuite nous résolvons le corps de la fonction en utilisant ceci :

^code resolve-function

C'est une méthode séparée puisque nous l'utiliserons aussi pour résoudre les méthodes Lox quand nous ajouterons les classes plus tard. Elle crée une nouvelle portée pour le corps et ensuite lie les variables pour chacun des paramètres de la fonction.

Une fois que c'est prêt, elle résout le corps de la fonction dans cette portée. C'est différent de comment l'interpréteur gère les déclarations de fonction. À l'_exécution_, déclarer une fonction ne fait rien avec le corps de la fonction. Le corps n'est pas touché jusqu'à plus tard quand la fonction est appelée. Dans une analyse _statique_, nous traversons immédiatement dans le corps ici et maintenant.

### Résoudre les autres nœuds d'arbre syntaxique

Cela couvre les coins intéressants des grammaires. Nous gérons chaque endroit où une variable est déclarée, lue, ou écrite, et chaque endroit où une portée est créée ou détruite. Même s'ils ne sont pas affectés par la résolution de variable, nous avons aussi besoin de méthodes visit pour tous les autres nœuds d'arbre syntaxique afin de récurser dans leurs sous-arbres. <span name="boring">Désolé</span> ce morceau est ennuyeux, mais supportez-moi. Nous allons aller genre "de haut en bas" et commencer avec les instructions.

<aside name="boring">

J'ai bien dit que le livre aurait chaque ligne de code unique pour ces interpréteurs. Je n'ai pas dit qu'elles seraient toutes excitantes.

</aside>

Une instruction d'expression contient une seule expression à traverser.

^code visit-expression-stmt

Une instruction if a une expression pour sa condition et une ou deux instructions pour les branches.

^code visit-if-stmt

Ici, nous voyons comment la résolution est différente de l'interprétation. Quand nous résolvons une instruction `if`, il n'y a pas de contrôle de flux. Nous résolvons la condition et les _deux_ branches. Là où une exécution dynamique entre seulement dans la branche qui _est_ lancée, une analyse statique est conservatrice -- elle analyse toute branche qui _pourrait_ être lancée. Puisque l'une ou l'autre pourrait être atteinte à l'exécution, nous résolvons les deux.

Comme les instructions d'expression, une instruction `print` contient une seule sous-expression.

^code visit-print-stmt

Même affaire pour return.

^code visit-return-stmt

Comme dans les instructions `if`, avec une instruction `while`, nous résolvons sa condition et résolvons le corps exactement une fois.

^code visit-while-stmt

Cela couvre toutes les instructions. Passons aux expressions...

Notre vieil ami l'expression binaire. Nous traversons dedans et résolvons les deux opérandes.

^code visit-binary-expr

Les appels sont similaires -- nous parcourons la liste d'arguments et les résolvons tous. La chose étant appelée est aussi une expression (habituellement une expression de variable), donc cela se fait résoudre aussi.

^code visit-call-expr

Les parenthèses sont faciles.

^code visit-grouping-expr

Les littéraux sont les plus faciles de tous.

^code visit-literal-expr

Une expression littérale ne mentionne aucune variable et ne contient aucune sous-expression donc il n'y a pas de travail à faire.

Puisqu'une analyse statique ne fait aucun contrôle de flux ou court-circuitage, les expressions logiques sont exactement les mêmes que les autres opérateurs binaires.

^code visit-logical-expr

Et, finalement, le dernier nœud. Nous résolvons son unique opérande.

^code visit-unary-expr

Avec toutes ces méthodes visit, le compilateur Java devrait être satisfait que Resolver implémente pleinement Stmt.Visitor et Expr.Visitor. Maintenant est un bon moment pour prendre une pause, prendre un en-cas, peut-être une petite sieste.

## Interpréter les Variables Résolues

Voyons à quoi notre résolveur est bon. Chaque fois qu'il visite une variable, il dit à l'interpréteur combien de portées il y a entre la portée courante et la portée où la variable est définie. À l'exécution, cela correspond exactement au nombre d'_environnements_ entre le courant et l'englobant où l'interpréteur peut trouver la valeur de la variable. Le résolveur passe ce nombre à l'interpréteur en appelant ceci :

^code resolve

Nous voulons stocker l'information de résolution quelque part pour que nous puissions l'utiliser quand l'expression de variable ou d'affectation est plus tard exécutée, mais où ? Un endroit évident est juste dans le nœud d'arbre syntaxique lui-même. C'est une approche correcte, et c'est où beaucoup de compilateurs stockent les résultats d'analyses comme celle-ci.

Nous pourrions faire cela, mais cela exigerait de trifouiller avec notre générateur d'arbre syntaxique. Au lieu de cela, nous prendrons une autre approche courante et le stockerons sur le <span name="side">côté</span> dans une map qui associe chaque nœud d'arbre syntaxique avec ses données résolues.

<aside name="side">

Je _pense_ que j'ai entendu cette map être appelée une "table latérale" (side table) puisque c'est une structure de données tabulaire qui stocke des données séparément des objets auxquels elle se rapporte. Mais chaque fois que j'essaie de Googler ce terme, j'obtiens des pages sur des meubles.

</aside>

Les outils interactifs comme les IDEs re-parsent et re-résolvent souvent incrémentalement des parties du programme de l'utilisateur. Il peut être difficile de trouver tous les bouts d'état qui ont besoin d'être recalculés quand ils se cachent dans le feuillage de l'arbre syntaxique. Un bénéfice de stocker ces données en dehors des nœuds est que cela rend facile de les _jeter_ -- effacez simplement la map.

^code locals-field (1 before, 2 after)

Vous pourriez penser que nous aurions besoin d'une sorte de structure d'arbre imbriquée pour éviter d'être confus quand il y a plusieurs expressions qui référencent la même variable, mais chaque nœud d'expression est son propre objet Java avec sa propre identité unique. Une seule map monolithique n'a aucun mal à les garder séparés.

Comme d'habitude, utiliser une collection exige de nous d'importer une paire de noms.

^code import-hash-map (1 before, 1 after)

Et :

^code import-map (1 before, 2 after)

### Accéder à une variable résolue

Notre interpréteur a maintenant accès à la localisation résolue de chaque variable. Finalement, nous arrivons à faire usage de cela. Nous remplaçons la méthode visit pour les expressions de variable par ceci :

^code call-look-up-variable (1 before, 1 after)

Cela délègue à :

^code look-up-variable

Il y a une paire de choses qui se passent ici. D'abord, nous cherchons la distance résolue dans la map. Rappelez-vous que nous avons résolu seulement les variables _locales_. Les globales sont traitées spécialement et ne finissent pas dans la map (d'où le nom `locals`). Donc, si nous ne trouvons pas une distance dans la map, elle doit être globale. Dans ce cas, nous la cherchons, dynamiquement, directement dans l'environnement global. Cela lance une erreur d'exécution si la variable n'est pas définie.

Si nous _obtenons_ une distance, nous avons une variable locale, et nous arrivons à tirer avantage des résultats de notre analyse statique. Au lieu d'appeler `get()`, nous appelons cette nouvelle méthode sur Environment :

^code get-at

La vieille méthode `get()` parcourt dynamiquement la chaîne d'environnements englobants, récurant chacun pour voir si la variable pourrait se cacher là-dedans quelque part. Mais maintenant nous savons exactement quel environnement dans la chaîne aura la variable. Nous l'atteignons en utilisant cette méthode assistante :

^code ancestor

Ceci marche un nombre fixe de sauts vers le haut de la chaîne parente et renvoie l'environnement là. Une fois que nous avons cela, `getAt()` renvoie simplement la valeur de la variable dans la map de cet environnement. Il n'a même pas à vérifier pour voir si la variable est là -- nous savons qu'elle le sera parce que le résolveur l'a déjà trouvée avant.

<aside name="coupled">

La façon dont l'interpréteur suppose que la variable est dans cette map ressemble à voler à l'aveugle. Le code de l'interpréteur fait confiance à ce que le résolveur a fait son travail et a résolu la variable correctement. Cela implique un couplage profond entre ces deux classes. Dans le résolveur, chaque ligne de code qui touche une portée doit avoir sa correspondance exacte dans l'interpréteur pour modifier un environnement.

J'ai senti ce couplage de première main parce qu'alors que j'écrivais le code pour le livre, je suis tombé sur une paire de bugs subtils où le code du résolveur et de l'interpréteur étaient légèrement désynchronisés. Traquer ceux-là était difficile. Un outil pour rendre cela plus facile est d'avoir l'interpréteur ASSERT explicitement -- en utilisant les instructions assert de Java ou un autre outil de validation -- le contrat qu'il attend que le résolveur ait déjà soutenu.

</aside>

### Assigner à une variable résolue

Nous pouvons aussi utiliser une variable en l'assignant. Les changements pour visiter une expression d'affectation sont similaires.

^code resolved-assign (2 before, 1 after)

Encore une fois, nous cherchons la distance de portée de la variable. Si non trouvée, nous supposons qu'elle est globale et la gérons de la même façon qu'avant. Sinon, nous appelons cette nouvelle méthode :

^code assign-at

Comme `getAt()` est à `get()`, `assignAt()` est à `assign()`. Elle parcourt un nombre fixe d'environnements, et ensuite bourre la nouvelle valeur dans cette map.

Ce sont les seuls changements à Interpreter. C'est pourquoi j'ai choisi une représentation pour nos données résolues qui était minimalement invasive. Tout le reste des nœuds continue de fonctionner comme ils le faisaient avant. Même le code pour modifier les environnements est inchangé.

### Lancer le résolveur

Nous avons besoin de _lancer_ réellement le résolveur, cependant. Nous insérons la nouvelle passe après que le parseur ait fait sa magie.

^code create-resolver (3 before, 1 after)

Nous ne lançons pas le résolveur s'il y a des erreurs de parsing. Si le code a une erreur de syntaxe, il ne va jamais tourner, donc il y a peu de valeur à le résoudre. Si la syntaxe est propre, nous disons au résolveur de faire son truc. Le résolveur a une référence à l'interpréteur et pousse les données de résolution directement dedans alors qu'il marche sur les variables. Quand l'interpréteur tourne ensuite, il a tout ce dont il a besoin.

Au moins, c'est vrai si le résolveur _réussit_. Mais qu'en est-il des erreurs pendant la résolution ?

## Erreurs de Résolution

Puisque nous faisons une passe d'analyse sémantique, nous avons une opportunité de rendre la sémantique de Lox plus précise, et d'aider les utilisateurs à attraper des bugs tôt avant de lancer leur code. Jetez un œil à ce mauvais garçon :

```lox
fun bad() {
  var a = "premier";
  var a = "second";
}
```

Nous permettons bien de déclarer plusieurs variables avec le même nom dans la portée _globale_, mais faire ainsi dans une portée locale est probablement une erreur. S'ils savaient que la variable existait déjà, ils l'auraient assignée au lieu d'utiliser `var`. Et s'ils ne savaient _pas_ qu'elle existait, ils n'avaient probablement pas l'intention d'écraser la précédente.

Nous pouvons détecter cette erreur statiquement pendant la résolution.

^code duplicate-variable (1 before, 1 after)

Quand nous déclarons une variable dans une portée locale, nous connaissons déjà les noms de chaque variable précédemment déclarée dans cette même portée. Si nous voyons une collision, nous rapportons une erreur.

### Erreurs de retour invalide

Voici un autre petit script méchant :

```lox
return "au niveau supérieur";
```

Ceci exécute une instruction `return`, mais ce n'est même pas à l'intérieur d'une fonction du tout. C'est du code de niveau supérieur. Je ne sais pas ce que l'utilisateur _pense_ qu'il va arriver, mais je ne pense pas que nous voulons que Lox permette cela.

Nous pouvons étendre le résolveur pour détecter cela statiquement. Tout comme nous suivons les portées alors que nous parcourons l'arbre, nous pouvons suivre si oui ou non le code que nous visitons actuellement est à l'intérieur d'une déclaration de fonction.

^code function-type-field (1 before, 2 after)

Au lieu d'un Booléen nu, nous utilisons cet enum drôle :

^code function-type

Cela semble un peu bête maintenant, mais nous lui ajouterons une paire de cas en plus plus tard et alors cela aura plus de sens. Quand nous résolvons une déclaration de fonction, nous passons cela dedans.

^code pass-function-type (2 before, 1 after)

Là-bas dans `resolveFunction()`, nous prenons ce paramètre et le stockons dans le champ avant de résoudre le corps.

^code set-current-function (1 after)

Nous planquons la valeur précédente du champ dans une variable locale d'abord. Rappelez-vous, Lox a des fonctions locales, donc vous pouvez imbriquer des déclarations de fonction arbitrairement profondément. Nous avons besoin de suivre non seulement que nous sommes dans une fonction, mais dans _combien_ nous sommes.

Nous pourrions utiliser une pile explicite de valeurs FunctionType pour cela, mais au lieu de cela nous ferons du ferroutage sur la JVM. Nous stockons la valeur précédente dans une locale sur la pile Java. Quand nous avons fini de résoudre le corps de la fonction, nous restaurons le champ à cette valeur.

^code restore-current-function (1 before, 1 after)

Maintenant que nous pouvons toujours dire si oui ou non nous sommes à l'intérieur d'une déclaration de fonction, nous vérifions cela quand nous résolvons une instruction `return`.

^code return-from-top (1 before, 1 after)

Propre, non ?

Il y a une pièce de plus. De retour dans la classe principale Lox qui coud tout ensemble, nous faisons attention de ne pas lancer l'interpréteur si des erreurs de parsing sont rencontrées. Cette vérification tourne _avant_ le résolveur pour que nous n'essayions pas de résoudre du code syntaxiquement invalide.

Mais nous avons aussi besoin de sauter l'interpréteur s'il y a des erreurs de résolution, donc nous ajoutons _une autre_ vérification.

^code resolution-error (1 before, 2 after)

Vous pourriez imaginer faire beaucoup d'autres analyses ici. Par exemple, si nous ajoutions des instructions `break` à Lox, nous voudrions probablement nous assurer qu'elles sont uniquement utilisées à l'intérieur de boucles.

Nous pourrions aller plus loin et rapporter des avertissements pour du code qui n'est pas nécessairement _faux_ mais n'est probablement pas utile. Par exemple, beaucoup d'IDEs avertiront si vous avez du code inatteignable après une instruction `return`, ou une variable locale dont la valeur n'est jamais lue. Tout cela serait assez facile à ajouter à notre passe de visite statique, ou comme des passes <span name="separate">séparées</span>.

<aside name="separate">

Le choix de combien d'analyses différentes regrouper dans une seule passe est difficile. Beaucoup de petites passes isolées, chacune avec sa propre responsabilité, sont plus simples à implémenter et maintenir. Cependant, il y a un coût réel à l'exécution à traverser l'arbre syntaxique lui-même, donc empaqueter plusieurs analyses dans une seule passe est habituellement plus rapide.

</aside>

Mais, pour l'instant, nous resterons avec cette quantité limitée d'analyse. La partie importante est que nous avons corrigé ce bizarre bug de cas limite ennuyeux, bien qu'il puisse être surprenant que cela ait pris autant de travail pour le faire.

<div class="challenges">

## Défis

1.  Pourquoi est-il sûr de définir avidement la variable liée au nom d'une fonction quand d'autres variables doivent attendre jusqu'après qu'elles soient initialisées avant qu'elles puissent être utilisées ?

2.  Comment d'autres langages que vous connaissez gèrent-ils les variables locales qui font référence au même nom dans leur initialiseur, comme :

    ```lox
    var a = "externe";
    {
      var a = a;
    }
    ```

    Est-ce une erreur d'exécution ? Erreur de compilation ? Autorisé ? Traitent-ils les variables globales différemment ? Êtes-vous d'accord avec leurs choix ? Justifiez votre réponse.

3.  Étendez le résolveur pour rapporter une erreur si une variable locale n'est jamais utilisée.

4.  Notre résolveur calcule dans _quel_ environnement la variable est trouvée, mais elle est toujours cherchée par nom dans cette map. Une représentation d'environnement plus efficace stockerait les variables locales dans un tableau et les chercherait par index.

    Étendez le résolveur pour associer un index unique pour chaque variable locale déclarée dans une portée. Quand vous résolvez un accès de variable, cherchez à la fois la portée dans laquelle la variable est et son index et stockez cela. Dans l'interpréteur, utilisez cela pour accéder rapidement à une variable par son index au lieu d'utiliser une map.

</div>
