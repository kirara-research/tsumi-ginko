import Vapor

func routes(_ app: Application) throws {
    app.get { _ async in
        Response(status: .ok, headers: ["Content-Type": "text/html"], body: Response.Body(string: """
            <p>Seeker of fire, conqueror of Dark.<br />
            I, too, sought fire, once.<br />
            With fire, they say, a true king can harness the curse.<br />
            A lie. But I knew no better...<br />
            Seeker of fire, you know not the depths of Dark within you.<br />
            It grows deeper still, the more flame you covet.<br />
            Flame, oh, flame...<br /></p>
        """))
    }
}
