import Foundation

enum SampleArticles {
    static let all: [Article] = [
        Article(
            id: "seed-anthropic-fable-mythos-directive-2026",
            title: "Anthropic suspends Fable and Mythos access",
            subtitle: "Anthropic says a US government directive required it to suspend access to two Claude-family models.",
            source: "Anthropic News",
            author: "Anthropic",
            category: .ai,
            readingMinutes: 3,
            publishNote: "Seed",
            summary: "Anthropic said it suspended access to Fable 5 and Mythos 5 after receiving a US government directive. The news connects model access, safety controls, and national security policy.",
            keyPoints: [
                "Anthropic suspended access to Fable 5 and Mythos 5.",
                "The company linked the action to a US government directive.",
                "The story shows how AI model access can become a policy issue."
            ],
            body: [
                "Anthropic said it suspended access to Fable 5 and Mythos 5 after receiving a directive from the US government. The company described the move as a response to official requirements, not a normal product update. That makes the story important for understanding AI policy.",
                "The case shows that advanced AI models are no longer only a technical topic. Governments may care about who can access powerful systems, how safeguards work, and whether a model could be misused. Companies must now think about product design, safety, and regulation together.",
                "A clear summary is: Anthropic paused access to two models because of a government directive. The larger lesson is that frontier AI products can quickly become part of debates about security, trust, and public policy."
            ],
            paragraphTranslations: [
                "Anthropic 表示，在收到美国政府的一项指令后，它暂停了对 Fable 5 和 Mythos 5 的访问。公司称此举是对官方要求的回应，而非常规的产品更新。这使得这则新闻对于理解 AI 政策很重要。",
                "这一案例表明，先进的 AI 模型已不再只是技术话题。政府可能会关心谁能使用强大的系统、安全机制如何运作，以及模型是否可能被滥用。如今企业必须把产品设计、安全与监管放在一起考虑。",
                "一个清晰的总结是：Anthropic 因一项政府指令暂停了两款模型的访问。更深层的启示是，前沿 AI 产品可能迅速卷入关于安全、信任与公共政策的讨论。"
            ],
            vocabulary: [
                ArticleVocabulary(word: "directive", meaningZh: "指令；正式要求", example: "The company followed a government directive."),
                ArticleVocabulary(word: "suspend", meaningZh: "暂停", example: "The service was suspended after the notice."),
                ArticleVocabulary(word: "compliance", meaningZh: "合规", example: "Compliance is important in regulated industries.")
            ],
            urlString: "https://www.anthropic.com/news/fable-mythos-access",
            imageURLString: "https://cdn.sanity.io/images/4zrzovbb/website/50159fff55088f12070cc8a56eb51ff61006b631-2400x1260.png",
            publishedAt: Date(timeIntervalSince1970: 1781136000)
        ),
        Article(
            id: "seed-anthropic-tcs-regulated-industries-2026",
            title: "Anthropic and TCS bring Claude to regulated industries",
            subtitle: "The partnership focuses on using Claude in sectors where security, compliance, and reliability matter.",
            source: "Anthropic News",
            author: "Anthropic",
            category: .ai,
            readingMinutes: 3,
            publishNote: "Seed",
            summary: "Anthropic and Tata Consultancy Services announced a partnership to bring Claude to regulated industries. The story highlights enterprise AI, compliance, and the practical work of deploying assistants in complex organizations.",
            keyPoints: [
                "Anthropic and TCS are working on Claude for regulated industries.",
                "The partnership emphasizes security and compliance.",
                "Enterprise AI often needs services, integration, and governance."
            ],
            body: [
                "Anthropic and Tata Consultancy Services announced a partnership to bring Claude into regulated industries. These are sectors such as banking, healthcare, insurance, or public services, where companies must follow strict rules. The goal is to make AI useful while keeping security and reliability in mind.",
                "The partnership matters because large organizations rarely adopt AI by simply turning on a tool. They need integration with existing systems, employee training, risk controls, and clear governance. A model can be powerful, but the deployment process decides whether it becomes useful.",
                "You can retell the news in one sentence: Anthropic is working with TCS so companies in rule-heavy industries can use Claude more safely. The broader trend is that AI providers are building partnerships to reach customers that require trust and structure."
            ],
            paragraphTranslations: [
                "Anthropic 与塔塔咨询服务公司（TCS）宣布建立合作，将 Claude 引入受监管行业。这些行业包括银行、医疗、保险或公共服务，企业必须遵守严格的规定。目标是在兼顾安全与可靠性的同时，让 AI 发挥作用。",
                "这项合作之所以重要，是因为大型机构很少只靠开启一个工具就采用 AI。它们需要与现有系统集成、对员工进行培训、建立风险控制以及清晰的治理。模型可能很强大，但部署过程才决定它是否真正有用。",
                "你可以用一句话复述这则新闻：Anthropic 正与 TCS 合作，让规则繁多行业的企业能更安全地使用 Claude。更大的趋势是，AI 提供商正通过建立合作伙伴关系，去触达那些需要信任与规范的客户。"
            ],
            vocabulary: [
                ArticleVocabulary(word: "regulated", meaningZh: "受监管的", example: "Banks work in a regulated industry."),
                ArticleVocabulary(word: "integration", meaningZh: "集成；整合", example: "Integration connects AI with existing systems."),
                ArticleVocabulary(word: "governance", meaningZh: "治理；管理机制", example: "AI governance sets rules for safe use.")
            ],
            urlString: "https://www.anthropic.com/news/tcs-anthropic-partnership",
            imageURLString: "https://www.anthropic.com/api/opengraph-illustration?name=Hand%20NodeLine&backgroundColor=olive",
            publishedAt: Date(timeIntervalSince1970: 1781136000)
        ),
        Article(
            id: "seed-anthropic-public-record-2026",
            title: "Anthropic publishes its first public record",
            subtitle: "Anthropic shared results from a public record process about AI policy, transparency, and public input.",
            source: "Anthropic News",
            author: "Anthropic",
            category: .ai,
            readingMinutes: 3,
            publishNote: "Seed",
            summary: "Anthropic published results from its first Public Record, a process designed to collect and share views about AI policy. The article is useful for learners because it connects AI governance with public discussion and institutional trust.",
            keyPoints: [
                "Anthropic shared results from a public record process.",
                "The topic connects AI policy with public input.",
                "The story uses governance vocabulary that appears often in AI news."
            ],
            body: [
                "Anthropic published results from its first Public Record, a process meant to gather and share public views on AI-related questions. The idea is to make policy discussions more visible. It also gives readers a way to see how an AI company explains its responsibilities.",
                "This kind of process matters because AI policy is no longer only a private company issue. Governments, researchers, users, and civil society groups all want to understand how powerful systems are built and controlled. Public input can help companies notice risks that internal teams may miss.",
                "A simple summary is: Anthropic is trying to make part of its policy conversation more public. The broader trend is that AI companies are under pressure to explain their choices, not just release faster models."
            ],
            paragraphTranslations: [
                "Anthropic 公布了其首份公共记录（Public Record）的结果，这是一个旨在收集并分享公众对 AI 相关问题看法的过程。其理念是让政策讨论更加公开，也让读者得以看到一家 AI 公司如何解释自身的责任。",
                "这类过程之所以重要，是因为 AI 政策已不再只是私营公司的事务。政府、研究者、用户和公民社会团体都想了解强大的系统是如何被构建和管控的。公众的意见可以帮助企业发现内部团队可能忽视的风险。",
                "一个简单的总结是：Anthropic 正试图让它的部分政策讨论更加公开。更大的趋势是，AI 公司正面临压力，需要解释自己的选择，而不只是发布更快的模型。"
            ],
            vocabulary: [
                ArticleVocabulary(word: "accountability", meaningZh: "问责；负责机制", example: "Accountability matters when AI affects the public."),
                ArticleVocabulary(word: "stakeholder", meaningZh: "利益相关者", example: "Stakeholders gave feedback on the policy."),
                ArticleVocabulary(word: "transparency", meaningZh: "透明度", example: "Transparency can build trust.")
            ],
            urlString: "https://www.anthropic.com/news/anthropic-public-record",
            imageURLString: "https://www.anthropic.com/api/opengraph-illustration?name=Hand%20Globe&backgroundColor=heather",
            publishedAt: Date(timeIntervalSince1970: 1781049600)
        ),
        Article(
            id: "seed-verge-anthropic-fable-guardrails-2026",
            title: "Anthropic changes course on Fable guardrails",
            subtitle: "The Verge reported that Anthropic adjusted a hidden safety measure after criticism from users.",
            source: "The Verge AI",
            author: "The Verge",
            category: .ai,
            readingMinutes: 3,
            publishNote: "Seed",
            summary: "The Verge reported that Anthropic changed course after users criticized hidden guardrails around Claude Fable. The story is useful for understanding transparency, safety design, and user trust in AI products.",
            keyPoints: [
                "Anthropic adjusted a safety measure after user criticism.",
                "The debate centered on hidden guardrails and transparency.",
                "AI companies must balance safety with user trust."
            ],
            body: [
                "The Verge reported that Anthropic changed course on a safety measure connected to Claude Fable. Some users criticized the guardrail because it was not clearly visible. The company then adjusted its approach, showing how quickly AI product decisions can become public debates.",
                "This story is important because safety controls are necessary, but users also want transparency. If a system changes output silently, people may wonder whether they understand the product. AI companies have to explain what their tools are doing and why certain limits exist.",
                "A short retelling could be: Anthropic modified a hidden guardrail after users pushed back. The broader lesson is that AI safety is not only a research question. It is also a communication problem between companies and the people who use their products."
            ],
            paragraphTranslations: [
                "据 The Verge 报道，Anthropic 调整了与 Claude Fable 相关的一项安全措施。一些用户批评该护栏，因为它并不明显可见。随后公司调整了做法，这显示出 AI 产品决策能多快地演变为公众争论。",
                "这则报道之所以重要，是因为安全控制是必要的，但用户同样希望有透明度。如果系统在不声不响中改变输出，人们可能会怀疑自己是否真正了解这款产品。AI 公司必须解释它们的工具在做什么，以及为什么存在某些限制。",
                "可以这样简短复述：在用户反对之后，Anthropic 修改了一项隐藏的护栏。更深层的启示是，AI 安全不仅是一个研究问题，也是企业与产品使用者之间的沟通问题。"
            ],
            vocabulary: [
                ArticleVocabulary(word: "guardrail", meaningZh: "护栏；安全限制", example: "The model uses guardrails to reduce risky output."),
                ArticleVocabulary(word: "transparency", meaningZh: "透明度", example: "Users asked for more transparency."),
                ArticleVocabulary(word: "criticism", meaningZh: "批评", example: "The company responded to criticism.")
            ],
            urlString: "https://www.theverge.com/ai-artificial-intelligence/948280/anthropic-claude-fable-invisible-distillation-guardrail",
            imageURLString: "https://platform.theverge.com/wp-content/uploads/sites/2/2026/06/STKB364_CLAUDE_D.jpg?quality=90&strip=all&crop=0%2C10.732984293194%2C100%2C78.534031413613&w=1200",
            publishedAt: Date(timeIntervalSince1970: 1781178043)
        ),
        Article(
            id: "seed-ars-anthropic-fable-mythos",
            title: "Anthropic shuts down Fable and Mythos models",
            subtitle: "Anthropic disabled access to new Claude-family models after a US export-control directive.",
            source: "Ars Technica AI",
            author: "Ars Technica",
            category: .ai,
            readingMinutes: 3,
            publishNote: "Seed",
            summary: "Anthropic shut off access to its Fable and Mythos models after receiving a US Commerce Department directive. The move shows how frontier AI products can quickly become part of national security and export-control debates.",
            keyPoints: [
                "Anthropic disabled access to Fable and Mythos after a government directive.",
                "Officials were reportedly concerned about possible cybersecurity risks.",
                "The story connects AI model access with national security policy."
            ],
            body: [
                "Anthropic shut off access to its Fable and Mythos models after receiving a directive from the US Commerce Department.",
                "The decision came shortly after the models launched, showing how quickly frontier AI systems can become part of national security debates.",
                "Officials were reportedly concerned that a jailbreak could let users bypass safeguards around cybersecurity, chemistry, or biology topics."
            ],
            paragraphTranslations: [
                "在收到美国商务部的一项指令后，Anthropic 关闭了对其 Fable 和 Mythos 模型的访问。",
                "这一决定是在这些模型发布后不久作出的，显示出前沿 AI 系统能多快地卷入国家安全的争论。",
                "据报道，官员们担心模型被越狱后，可能让用户绕过围绕网络安全、化学或生物等话题的安全防护。"
            ],
            vocabulary: [
                ArticleVocabulary(word: "directive", meaningZh: "指令；正式要求", example: "The company received a government directive."),
                ArticleVocabulary(word: "safeguard", meaningZh: "保护措施；安全机制", example: "The model includes safeguards for risky topics."),
                ArticleVocabulary(word: "export control", meaningZh: "出口管制", example: "Export controls can limit access to advanced technology.")
            ],
            urlString: "https://arstechnica.com/ai/2026/06/anthropic-shuts-down-fable-mythos-models-following-trump-admin-directive/",
            imageURLString: "https://cdn.arstechnica.net/wp-content/uploads/2026/06/fable5-1152x648.webp",
            publishedAt: Date(timeIntervalSince1970: 1781319634)
        ),
        Article(
            id: "seed-verge-anthropic-china-mythos",
            title: "China may have accessed Mythos",
            subtitle: "A report says concerns about Chinese access helped drive restrictions around Anthropic's model.",
            source: "The Verge AI",
            author: "The Verge",
            category: .ai,
            readingMinutes: 3,
            publishNote: "Seed",
            summary: "A report said the White House restricted Anthropic's Mythos model partly because of concerns that a group linked to China may have accessed it. The story highlights how AI model access is becoming a geopolitical issue.",
            keyPoints: [
                "US officials reportedly worried about foreign access to Anthropic's model.",
                "Advanced models can become part of geopolitical competition.",
                "The story includes useful security and policy vocabulary."
            ],
            body: [
                "A new report said US officials were concerned that Anthropic's Mythos model may have been accessed by a group linked to China.",
                "If a foreign government had access to an advanced model, it could try to study the model or train another system to copy some of its behavior.",
                "This is why AI access is increasingly discussed not only as a product issue, but also as a security and policy issue."
            ],
            paragraphTranslations: [
                "一份新报告称，美国官员担心 Anthropic 的 Mythos 模型可能已被一个与中国有关联的团体访问。",
                "如果外国政府能够访问一款先进模型，它可能会试图研究该模型，或训练另一套系统来复制它的部分行为。",
                "正因如此，AI 的访问权限越来越多地不仅被当作产品问题来讨论，也被视为安全与政策问题。"
            ],
            vocabulary: [
                ArticleVocabulary(word: "restriction", meaningZh: "限制", example: "The government introduced new restrictions."),
                ArticleVocabulary(word: "geopolitical", meaningZh: "地缘政治的", example: "AI is becoming a geopolitical issue."),
                ArticleVocabulary(word: "reverse engineer", meaningZh: "逆向工程；反向分析", example: "Researchers tried to reverse engineer the system.")
            ],
            urlString: "https://www.theverge.com/ai-artificial-intelligence/949644/china-white-house-anthropic-mythos",
            imageURLString: "https://platform.theverge.com/wp-content/uploads/sites/2/2026/01/STK269_ANTHROPIC_2_C.jpg?quality=90&strip=all&crop=0,0,100,100",
            publishedAt: Date(timeIntervalSince1970: 1781450875)
        ),
        Article(
            id: "seed-venturebeat-google-search-ai",
            title: "Google redesigned search for the AI era",
            subtitle: "Google is turning the search box into a multimodal, AI-driven conversation interface.",
            source: "VentureBeat AI",
            author: "VentureBeat",
            category: .ai,
            readingMinutes: 4,
            publishNote: "Seed",
            summary: "Google redesigned its search box to support longer questions, files, images, and AI-powered follow-up conversations. The change shows how search is moving from short keywords toward natural-language interaction.",
            keyPoints: [
                "Google is making search more conversational and multimodal.",
                "The search box can support richer inputs such as files and images.",
                "The change reflects a broader shift in how people use AI products."
            ],
            body: [
                "Google redesigned the search box for the first time in many years, turning it from a simple keyword input into a more flexible AI interface.",
                "The new experience is designed for longer questions and multimodal inputs such as images, files, videos, and open browser tabs.",
                "Google also wants users to continue into follow-up conversations instead of choosing between a traditional results page and an AI experience."
            ],
            paragraphTranslations: [
                "谷歌多年来首次重新设计了搜索框，把它从简单的关键词输入变成了一个更灵活的 AI 交互界面。",
                "新的体验专为更长的问题和多模态输入而设计，例如图片、文件、视频以及打开的浏览器标签页。",
                "谷歌还希望用户能继续进行后续对话，而不必在传统的结果页和 AI 体验之间做出取舍。"
            ],
            vocabulary: [
                ArticleVocabulary(word: "multimodal", meaningZh: "多模态的", example: "The system supports multimodal input."),
                ArticleVocabulary(word: "interface", meaningZh: "界面；交互方式", example: "The search box became an AI interface."),
                ArticleVocabulary(word: "seamless", meaningZh: "无缝的；顺畅的", example: "The app offers a seamless experience.")
            ],
            urlString: "https://venturebeat.com/technology/google-just-redesigned-the-search-box-for-the-first-time-in-25-years-heres-why-it-matters-more-than-you-think",
            imageURLString: "https://images.ctfassets.net/jdtwqhzvc2n1/1TD0Sl7Zq6nnBSZMK9FXpl/41ce2cc6da055da7647670c71ba8aa6b/Nuneybits_Vector_art_of_an_oversized_white_search_bar_rimmed_in_695cac3f-1536-4438-acc1-51c16e2ff51f.webp?w=300&q=30",
            publishedAt: Date(timeIntervalSince1970: 1779212700)
        )
    ]

    static func bundledEdition(for dateKey: String) -> DailyEdition {
        let morning = all[0].withEdition(
            date: dateKey,
            slot: .morning,
            status: .approved,
            learningContent: anthropicAccessLearningContent
        )
        let afternoon = all[1].withEdition(
            date: dateKey,
            slot: .afternoon,
            status: .approved,
            learningContent: regulatedIndustriesLearningContent
        )

        return DailyEdition(
            schemaVersion: 1,
            date: dateKey,
            generatedAt: Date(timeIntervalSince1970: 1_781_500_000),
            status: .approved,
            articles: [morning, afternoon]
        )
    }

    private static let anthropicAccessLearningContent = ArticleLearningContent(
        easy: ArticleLearningVersion(
            paragraphs: [
                "Anthropic stopped access to two AI models called Fable 5 and Mythos 5. The company said it received an order from the US government.",
                "This was not a normal product change. It shows that powerful AI models can become a national security issue. Governments may decide who can use a model and what safety rules it needs.",
                "The main point is simple: AI companies now need to think about technology, safety, and government policy at the same time."
            ],
            paragraphTranslations: [
                "Anthropic 停止了对两款名为 Fable 5 和 Mythos 5 的 AI 模型的访问。该公司表示，它收到了美国政府的命令。",
                "这不是一次普通的产品调整。它说明强大的 AI 模型可能成为国家安全问题。政府可能决定谁能使用模型，以及模型需要哪些安全规则。",
                "核心很简单：AI 公司现在必须同时考虑技术、安全和政府政策。"
            ],
            targetWords: 100,
            cefr: "A2-B1"
        ),
        standard: ArticleLearningVersion(
            paragraphs: [
                "Anthropic suspended access to Fable 5 and Mythos 5 after receiving a directive from the US government. The company described the move as a response to an official requirement rather than a normal product update.",
                "The decision matters because advanced AI models are no longer only technical products. Governments are increasingly concerned about who can access powerful systems, whether safeguards can be bypassed, and how the technology could affect national security.",
                "The case shows that AI companies must manage product design, safety controls, and regulation together. A model release can quickly become a policy issue when officials believe its capabilities may create public or security risks."
            ],
            paragraphTranslations: [
                "Anthropic 在收到美国政府指令后，暂停了 Fable 5 和 Mythos 5 的访问。公司称此举是为了回应官方要求，而不是普通的产品更新。",
                "这一决定很重要，因为先进 AI 模型已不再只是技术产品。政府越来越关注谁能使用强大系统、安全措施是否可能被绕过，以及技术会如何影响国家安全。",
                "这个案例说明，AI 公司必须同时管理产品设计、安全控制与监管。当政府认为模型能力可能带来公共或安全风险时，一次模型发布会迅速变成政策问题。"
            ],
            targetWords: 150,
            cefr: "B1-B2"
        ),
        vocabulary: [
            ArticleVocabulary(word: "suspend", meaningZh: "暂停；暂时停止", phonetic: "/səˈspend/", example: "The company suspended access to the service.", exampleZh: "该公司暂停了这项服务的访问。"),
            ArticleVocabulary(word: "directive", meaningZh: "正式指令；命令", phonetic: "/dəˈrektɪv/", example: "The agency issued a new directive.", exampleZh: "该机构发布了一项新指令。"),
            ArticleVocabulary(word: "requirement", meaningZh: "要求；必要条件", phonetic: "/rɪˈkwaɪərmənt/", example: "Safety testing is a legal requirement.", exampleZh: "安全测试是一项法律要求。"),
            ArticleVocabulary(word: "safeguard", meaningZh: "保护措施；安全机制", phonetic: "/ˈseɪfɡɑːrd/", example: "The model includes safeguards against misuse.", exampleZh: "该模型包含防止滥用的安全措施。"),
            ArticleVocabulary(word: "bypass", meaningZh: "绕过；规避", phonetic: "/ˈbaɪpæs/", example: "Attackers tried to bypass the controls.", exampleZh: "攻击者试图绕过控制措施。"),
            ArticleVocabulary(word: "regulation", meaningZh: "监管；法规", phonetic: "/ˌreɡjəˈleɪʃn/", example: "New regulation may affect AI companies.", exampleZh: "新的监管规定可能影响 AI 公司。")
        ],
        generatedAt: Date(timeIntervalSince1970: 1_781_500_000),
        sourceFingerprint: "anthropic-access-v1"
    )

    private static let regulatedIndustriesLearningContent = ArticleLearningContent(
        easy: ArticleLearningVersion(
            paragraphs: [
                "Anthropic and Tata Consultancy Services are working together. They want to bring Claude to industries with strict rules, such as banking, healthcare, and insurance.",
                "These companies need strong security and clear controls. They cannot simply turn on an AI tool. They must connect it to old systems, train workers, and follow regulations.",
                "The partnership shows an important trend: AI companies need trusted service partners to enter large and highly regulated businesses."
            ],
            paragraphTranslations: [
                "Anthropic 正与塔塔咨询服务公司合作。他们希望把 Claude 带入银行、医疗和保险等规则严格的行业。",
                "这些公司需要强大的安全保障和清晰的控制机制。它们不能只是打开一个 AI 工具，还必须接入旧系统、培训员工并遵守法规。",
                "这项合作体现了一个重要趋势：AI 公司需要可信赖的服务伙伴，才能进入大型且高度受监管的行业。"
            ],
            targetWords: 100,
            cefr: "A2-B1"
        ),
        standard: ArticleLearningVersion(
            paragraphs: [
                "Anthropic and Tata Consultancy Services announced a partnership to bring Claude into regulated industries such as banking, healthcare, insurance, and public services. These sectors must meet strict requirements for security, privacy, and reliability.",
                "Large organizations rarely adopt AI by simply activating a new tool. They need to integrate it with existing systems, train employees, set risk controls, and create clear governance for how the model may be used.",
                "The partnership highlights a broader enterprise AI trend. Model providers increasingly rely on experienced service companies to turn technical capability into a trustworthy system that can operate inside complex organizations."
            ],
            paragraphTranslations: [
                "Anthropic 与塔塔咨询服务公司宣布合作，把 Claude 引入银行、医疗、保险和公共服务等受监管行业。这些行业必须满足严格的安全、隐私和可靠性要求。",
                "大型组织很少能通过简单启用一个新工具来采用 AI。它们需要把 AI 与现有系统集成、培训员工、设置风险控制，并明确模型的使用治理规则。",
                "这项合作体现了企业 AI 的更广泛趋势：模型提供商越来越依赖有经验的服务公司，把技术能力变成能在复杂组织中运行的可信系统。"
            ],
            targetWords: 150,
            cefr: "B1-B2"
        ),
        vocabulary: [
            ArticleVocabulary(word: "regulated", meaningZh: "受监管的", phonetic: "/ˈreɡjuleɪtɪd/", example: "Banks operate in a regulated industry.", exampleZh: "银行在受监管的行业中运营。"),
            ArticleVocabulary(word: "compliance", meaningZh: "合规；遵守规定", phonetic: "/kəmˈplaɪəns/", example: "The team checks the system for compliance.", exampleZh: "团队检查该系统是否合规。"),
            ArticleVocabulary(word: "reliability", meaningZh: "可靠性", phonetic: "/rɪˌlaɪəˈbɪləti/", example: "Hospitals require high reliability.", exampleZh: "医院要求很高的可靠性。"),
            ArticleVocabulary(word: "integrate", meaningZh: "整合；集成", phonetic: "/ˈɪntɪɡreɪt/", example: "The company will integrate AI with its database.", exampleZh: "公司将把 AI 与数据库集成。"),
            ArticleVocabulary(word: "governance", meaningZh: "治理；管理机制", phonetic: "/ˈɡʌvərnəns/", example: "Good governance defines how AI may be used.", exampleZh: "良好的治理会规定 AI 可以如何使用。"),
            ArticleVocabulary(word: "enterprise", meaningZh: "企业级的；大型企业", phonetic: "/ˈentərpraɪz/", example: "Enterprise customers need stronger controls.", exampleZh: "企业客户需要更强的控制措施。")
        ],
        generatedAt: Date(timeIntervalSince1970: 1_781_500_000),
        sourceFingerprint: "anthropic-tcs-v1"
    )
}
