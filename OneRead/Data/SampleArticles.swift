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
                "For English learners, the key words include directive, suspend, access, safeguards, national security, and compliance. These words often appear when technology companies respond to regulators or government agencies.",
                "A clear summary is: Anthropic paused access to two models because of a government directive. The larger lesson is that frontier AI products can quickly become part of debates about security, trust, and public policy."
            ],
            paragraphTranslations: [],
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
                "For English learners, this article is a good place to study words like regulated, industry, partnership, compliance, integration, and governance. These words appear often in enterprise technology news and help explain how AI moves into serious business settings.",
                "You can retell the news in one sentence: Anthropic is working with TCS so companies in rule-heavy industries can use Claude more safely. The broader trend is that AI providers are building partnerships to reach customers that require trust and structure."
            ],
            paragraphTranslations: [],
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
                "For English learners, focus on words such as public record, transparency, accountability, policy, stakeholder, and governance. These words are common when people discuss trust in AI companies and the social impact of new technology.",
                "A simple summary is: Anthropic is trying to make part of its policy conversation more public. The broader trend is that AI companies are under pressure to explain their choices, not just release faster models."
            ],
            paragraphTranslations: [],
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
                "For English learners, focus on words such as guardrail, transparency, criticism, adjust, safety measure, and trust. These terms are common in AI articles about product design and model behavior.",
                "A short retelling could be: Anthropic modified a hidden guardrail after users pushed back. The broader lesson is that AI safety is not only a research question. It is also a communication problem between companies and the people who use their products."
            ],
            paragraphTranslations: [],
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
                "Officials were reportedly concerned that a jailbreak could let users bypass safeguards around cybersecurity, chemistry, or biology topics.",
                "For English learners, this story is useful because it includes common technology and policy vocabulary such as directive, export controls, safeguards, and national security."
            ],
            paragraphTranslations: [],
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
                "This is why AI access is increasingly discussed not only as a product issue, but also as a security and policy issue.",
                "For learners, notice phrases like export restrictions, national security risk, and reverse engineer."
            ],
            paragraphTranslations: [],
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
                "Google also wants users to continue into follow-up conversations instead of choosing between a traditional results page and an AI experience.",
                "For English learners, this story is useful because it includes common product vocabulary such as interface, multimodal, query, and seamless."
            ],
            paragraphTranslations: [],
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
}
